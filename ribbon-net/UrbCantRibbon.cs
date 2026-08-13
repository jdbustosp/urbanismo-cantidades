// Pestana CANTIDADES dinamica (fase .NET de Urbanismo Cantidades).
// El motor sigue siendo urbanismo_cantidades.lsp: cada boton dispara un
// comando LISP via SendStringToExecute. Este DLL solo dibuja la cinta.
//
// SINTAXIS C# 5 A PROPOSITO (sin interpolacion $"", sin ?., sin =>
// en miembros): el mismo archivo compila con el csc.exe integrado de
// Windows (.NET Framework 4.8, AutoCAD 2019-2024) y con dotnet SDK 8
// (AutoCAD 2025+). No modernizar la sintaxis sin revisar compilar_2023.
//
// Jerarquia del panel Crear (2026-08-11 v2, pedido del usuario):
//   [Urbanismo] -> 10 simbolos GRANDES con su nombre debajo:
//     Via, Anden, Rampa, Zona verde, Prefabricado,
//     Red sanitaria ->  Tramo, Pozo sanitario
//     Red pluvial   ->  Tramo, Sumidero, Pozo
//     Acueducto     ->  Tramo, Accesorios
//     Media tension ->  Tramo MT, Tramo BT, Alumbrado, Camara, Luminaria
//   Todo aparece EN EL MISMO ESPACIO del panel (swap en vivo), con "<"
//   para volver un nivel.
using System;
using System.Collections;
using System.ComponentModel;
using System.IO;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.Windows.Data;
using Autodesk.Windows;

[assembly: ExtensionApplication(typeof(UrbanismoCantidades.RibbonApp))]

namespace UrbanismoCantidades
{
    public class RibbonApp : IExtensionApplication
    {
        private const string TabId = "URBCANT_TAB_NET";
        private static bool _built;
        private static bool _legacyChecked;
        private static RibbonPanelSource _crearSource;
        private static string _dir;
        private static bool _memoryPropertyRegistered;

        public void Initialize()
        {
            try
            {
                _dir = Path.GetDirectoryName(
                    System.Reflection.Assembly.GetExecutingAssembly().Location);
                Log("Initialize");
                if (System.Diagnostics.Process.GetCurrentProcess().ProcessName
                        .Equals("accoreconsole", StringComparison.OrdinalIgnoreCase))
                {
                    Log("Core Console: interfaz y desplegable omitidos");
                    return;
                }
                if (ComponentManager.Ribbon == null)
                    ComponentManager.ItemInitialized += OnItemInitialized;
                else
                    BuildTab();
                Application.Idle += OnIdleRegisterMemoryProperty;
                // el partial CUIX viejo (si sigue registrado en el perfil)
                // duplicaria la pestana: se descarga solo, una vez, cuando
                // haya documento activo
                Application.Idle += OnIdleUnloadLegacy;
            }
            catch (System.Exception ex) { Log("ERROR Initialize: " + ex.Message); }
        }

        public void Terminate()
        {
            Application.Idle -= OnIdleRegisterMemoryProperty;
            if (_memoryPropertyRegistered)
            {
                ExtendedPropertyManager.RegisterExtendedProperty -=
                    OnRegisterExtendedProperty;
                _memoryPropertyRegistered = false;
            }
        }

        private static void OnIdleRegisterMemoryProperty(object sender, EventArgs e)
        {
            Application.Idle -= OnIdleRegisterMemoryProperty;
            try { RegisterMemoryPropertyDropdown(); }
            catch (System.Exception ex)
            {
                Log("ERROR registro desplegable MEMORIAS: " + ex.Message);
            }
        }

        private static void RegisterMemoryPropertyDropdown()
        {
            if (_memoryPropertyRegistered) return;
            ExtendedPropertyManager.RegisterExtendedProperty +=
                OnRegisterExtendedProperty;
            _memoryPropertyRegistered = true;
            Log("Desplegable MEMORIAS registrado");
        }

        private static void OnRegisterExtendedProperty(
            object sender, ExtendedPropertyEventArgs e)
        {
            try
            {
                if (e == null || e.PropertyDesc == null) return;
                if (e.PropertyDesc is MemoryPropertyDescriptor) return;
                string identity =
                    (e.PropertyName ?? "") + " " +
                    (e.PropertyDesc.Name ?? "") + " " +
                    (e.PropertyDesc.DisplayName ?? "");
                if (identity.ToUpperInvariant().IndexOf("MEMORIAS") < 0)
                    return;
                e.PropertyDesc = new MemoryPropertyDescriptor(e.PropertyDesc);
            }
            catch (System.Exception ex)
            {
                Log("ERROR desplegable MEMORIAS: " + ex.Message);
            }
        }

        private sealed class MemoryVisibilityConverter : TypeConverter
        {
            private static readonly StandardValuesCollection Values =
                new StandardValuesCollection(
                    new string[] { "MOSTRAR", "OCULTAR" });

            public override bool GetStandardValuesSupported(
                ITypeDescriptorContext context)
            {
                return true;
            }

            public override bool GetStandardValuesExclusive(
                ITypeDescriptorContext context)
            {
                return true;
            }

            public override StandardValuesCollection GetStandardValues(
                ITypeDescriptorContext context)
            {
                return Values;
            }
        }

        private sealed class MemoryPropertyDescriptor : PropertyDescriptor
        {
            private readonly PropertyDescriptor _inner;
            private static readonly TypeConverter Dropdown =
                new MemoryVisibilityConverter();

            public MemoryPropertyDescriptor(PropertyDescriptor inner)
                : base(inner)
            {
                _inner = inner;
            }

            public override Type ComponentType { get { return _inner.ComponentType; } }
            public override bool IsReadOnly { get { return _inner.IsReadOnly; } }
            public override Type PropertyType { get { return typeof(string); } }
            public override TypeConverter Converter { get { return Dropdown; } }
            public override bool SupportsChangeEvents
            {
                get { return _inner.SupportsChangeEvents; }
            }

            public override bool CanResetValue(object component)
            {
                return _inner.CanResetValue(component);
            }

            public override object GetValue(object component)
            {
                object value = _inner.GetValue(component);
                string text = value == null ? "" : value.ToString().ToUpperInvariant();
                return (text.IndexOf("VISIB") >= 0 ||
                        text.IndexOf("MOSTRAR") >= 0)
                    ? "MOSTRAR" : "OCULTAR";
            }

            public override void ResetValue(object component)
            {
                _inner.ResetValue(component);
            }

            public override void SetValue(object component, object value)
            {
                string selected = value == null ? "" : value.ToString();
                _inner.SetValue(
                    component,
                    selected.ToUpperInvariant() == "MOSTRAR"
                        ? "MOSTRAR" : "OCULTAR");
                OnValueChanged(component, EventArgs.Empty);
            }

            public override bool ShouldSerializeValue(object component)
            {
                return _inner.ShouldSerializeValue(component);
            }
        }

        private static void OnItemInitialized(object sender, RibbonItemEventArgs e)
        {
            if (ComponentManager.Ribbon != null)
            {
                ComponentManager.ItemInitialized -= OnItemInitialized;
                BuildTab();
            }
        }

        private static void OnIdleUnloadLegacy(object sender, EventArgs e)
        {
            // Descarga el partial CUIX legado por COM (MenuGroups.Unload):
            // la via de comando (CUIUNLOAD) abria un dialogo con FILEDIA=1
            // y nunca descargaba -- por eso la pestana salia duplicada.
            try
            {
                if (_legacyChecked) { Application.Idle -= OnIdleUnloadLegacy; return; }
                _legacyChecked = true;
                Application.Idle -= OnIdleUnloadLegacy;
                dynamic acad = Application.AcadApplication;
                dynamic groups = acad.MenuGroups;
                int count = (int)groups.Count;
                for (int i = 0; i < count; i++)
                {
                    dynamic g = groups.Item(i);
                    string name = (string)g.Name;
                    if (name != null && name.ToUpper() == "CANTIDADES")
                    {
                        g.Unload();
                        Log("Partial CUIX legado CANTIDADES descargado por COM");
                        break;
                    }
                }
            }
            catch (System.Exception ex) { Log("ERROR IdleLegacy: " + ex.Message); }
        }

        private static void BuildTab()
        {
            try
            {
                if (_built) return;
                RibbonControl ribbon = ComponentManager.Ribbon;
                if (ribbon == null) return;
                if (ribbon.FindTab(TabId) != null) { _built = true; return; }

                RibbonTab tab = new RibbonTab();
                tab.Title = "CANTIDADES";
                tab.Id = TabId;
                ribbon.Tabs.Add(tab);

                _crearSource = new RibbonPanelSource();
                _crearSource.Title = "Crear";
                RibbonPanel crearPanel = new RibbonPanel();
                crearPanel.Source = _crearSource;
                tab.Panels.Add(crearPanel);
                ShowCrearRoot();

                tab.Panels.Add(MakePanel("Editar", new string[][] {
                    new string[] { "Editar", "EDITAR", "editar", "L" },
                    new string[] { "Etapas", "ETAPAS", "etapas", "L" } }));
                // Cantidades absorbe Excel agrupado en UN boton desplegable
                // (2026-08-11 v3, pedido del usuario)
                RibbonPanel cantPanel = MakePanel("Cantidades", new string[][] {
                    new string[] { "Cuadro", "QCUADRO", "qcuadro", "L" },
                    new string[] { "Memoria", "QMEMORIA", "qmemoria", "L" },
                    new string[] { "Verificacion", "QVERIFICACION", "qverificacion", "L" } });
                cantPanel.Source.Items.Add(MakeExcelGroup());
                tab.Panels.Add(cantPanel);
                // solo Ajustes (2026-08-11 v4: "Perfiles" duplicaba la
                // opcion que ya vive dentro de Ajustes)
                tab.Panels.Add(MakePanel("Configuracion", new string[][] {
                    new string[] { "Ajustes", "AJUSTES", "ajustes", "L" } }));

                _built = true;
                Log("Tab construida: " + tab.Panels.Count + " paneles");
            }
            catch (System.Exception ex) { Log("ERROR BuildTab: " + ex.Message); }
        }

        // --- panel Crear dinamico (jerarquia v3, 2026-08-11) -----------
        //  [Urbanismo externo]
        //    Urbanismo      -> Via, Anden, Rampa, Zona verde, Prefabricado
        //    Redes humedas  -> Acueducto     -> Tramo, Accesorios
        //                      Alcantarillado -> Tramo, Pozo sanitario
        //                      Pluvial        -> Tramo, Sumidero, Pozo
        //    Redes secas    -> Media tension  -> Tramo MT, Tramo BT, Camara
        //                      Alumbrado      -> Tramo alumbrado, Luminaria

        private static void ShowCrearRoot()
        {
            _crearSource.Items.Clear();
            RibbonButton urb = MakeBig("Urbanismo externo", null, "urbanismo");
            urb.CommandHandler = new NavHandler("ext");
            _crearSource.Items.Add(urb);
        }

        private static void ShowSub(string which)
        {
            _crearSource.Items.Clear();
            if (which == "ext")
            {
                AddBack("root");
                AddBigNav("Urbanismo", "urb", "urbanismo");
                AddBigNav("Redes humedas", "hum", "tpluvial");
                AddBigNav("Redes secas", "sec", "mediatension");
            }
            else if (which == "urb")
            {
                AddBack("ext");
                AddBigCmd("Via", "VIA", "via");
                AddBigCmd("Anden", "ANDEN", "anden");
                AddBigCmd("Rampa", "RAMPA", "rampa");
                AddBigCmd("Zona verde", "ZONAVERDE", "zonaverde");
                AddBigCmd("Prefabricado", "PREFABRICADO", "prefabricado");
            }
            else if (which == "hum")
            {
                AddBack("ext");
                AddBigNav("Acueducto", "acu", "tacueducto");
                AddBigNav("Alcantarillado", "alc", "tsanitario");
                AddBigNav("Pluvial", "plu", "tpluvial");
            }
            else if (which == "acu")
            {
                AddBack("hum");
                AddBigCmd("Tramo", "TACUEDUCTO", "tacueducto");
                AddBigCmd("Accesorios", "ACCESORIO", "accesorio");
            }
            else if (which == "alc")
            {
                AddBack("hum");
                AddBigCmd("Tramo", "TSANITARIO", "tsanitario");
                AddBigCmd("Pozo sanitario", "POZOSAN", "pozosan");
            }
            else if (which == "plu")
            {
                AddBack("hum");
                AddBigCmd("Tramo", "TPLUVIAL", "tpluvial");
                AddBigCmd("Sumidero", "SUMIDERO", "sumidero");
                AddBigCmd("Pozo", "POZOPLU", "pozoplu");
            }
            else if (which == "sec")
            {
                AddBack("ext");
                AddBigNav("Media tension", "mt", "mediatension");
                AddBigNav("Alumbrado", "alum", "luminaria");
            }
            else if (which == "mt")
            {
                AddBack("sec");
                AddBigCmd("Tramo MT", "TMT", "mediatension");
                AddBigCmd("Tramo BT", "TBT", "camara");
                AddBigCmd("Camara", "CAMARA", "camara");
            }
            else if (which == "alum")
            {
                AddBack("sec");
                AddBigCmd("Tramo alumbrado", "TAP", "luminaria");
                AddBigCmd("Luminaria", "LUMINARIA", "luminaria");
            }
        }

        private static void AddBack(string target)
        {
            RibbonButton back = new RibbonButton();
            back.Text = "<";
            back.ShowText = true;
            back.ShowImage = false;
            back.Size = RibbonItemSize.Large;
            back.Orientation = System.Windows.Controls.Orientation.Vertical;
            back.ToolTip = "Volver";
            back.CommandHandler = new NavHandler(target);
            _crearSource.Items.Add(back);
        }

        private static void AddBigCmd(string text, string command, string icon)
        {
            _crearSource.Items.Add(MakeBig(text, command, icon));
        }

        private static void AddBigNav(string text, string target, string icon)
        {
            RibbonButton b = MakeBig(text, null, icon);
            b.CommandHandler = new NavHandler(target);
            _crearSource.Items.Add(b);
        }

        private class NavHandler : ICommand
        {
            private readonly string _target;
            public NavHandler(string target) { _target = target; }
            public bool CanExecute(object p) { return true; }
            public event EventHandler CanExecuteChanged { add { } remove { } }
            public void Execute(object p)
            {
                try
                {
                    if (_target == "root") ShowCrearRoot();
                    else ShowSub(_target);
                }
                catch (System.Exception ex) { Log("ERROR Nav: " + ex.Message); }
            }
        }

        // Boton desplegable "Excel" con las 4 acciones adentro (siempre
        // muestra "Excel"; la lista se abre al oprimirlo)
        private static RibbonSplitButton MakeExcelGroup()
        {
            RibbonSplitButton sb = new RibbonSplitButton();
            sb.Text = "Excel";
            sb.ShowText = true;
            sb.ToolTip = "Exportar y sincronizar con Excel";
            sb.Size = RibbonItemSize.Large;
            sb.Orientation = System.Windows.Controls.Orientation.Vertical;
            sb.IsSplit = false;
            sb.IsSynchronizedWithCurrentItem = false;
            sb.ListStyle = RibbonSplitButtonListStyle.List;
            BitmapImage img16 = LoadIcon("cant_qexcel_16.png");
            BitmapImage img32 = LoadIcon("cant_qexcel_32.png");
            if (img16 != null) sb.Image = img16;
            if (img32 != null) sb.LargeImage = img32;
            sb.ShowImage = true;
            sb.Items.Add(MakeBig("Exportar Excel", "QEXCEL", "qexcel"));
            sb.Items.Add(MakeBig("Actualizar Excel vinculado", "QACTUALIZAR", "qactualizar"));
            sb.Items.Add(MakeBig("Vincular Excel maestro", "QVINCULAR", "qvincular"));
            sb.Items.Add(MakeBig("Desvincular Excel", "QDESVINCULAR", "qdesvincular"));
            return sb;
        }

        // --- fabrica de paneles y botones -----------------------------

        private static RibbonButton MakeBig(string text, string command, string icon)
        {
            // boton GRANDE con el nombre debajo del simbolo (pedido del
            // usuario: "abajo de cada simbolo este la descripcion")
            RibbonButton b = new RibbonButton();
            b.Text = text;
            b.ShowText = true;
            b.ToolTip = text;
            b.Size = RibbonItemSize.Large;
            b.Orientation = System.Windows.Controls.Orientation.Vertical;
            BitmapImage img16 = LoadIcon("cant_" + icon + "_16.png");
            BitmapImage img32 = LoadIcon("cant_" + icon + "_32.png");
            if (img16 != null) b.Image = img16;
            if (img32 != null) b.LargeImage = img32;
            b.ShowImage = (img16 != null || img32 != null);
            if (command != null) b.CommandHandler = new CmdHandler(command);
            return b;
        }

        private static RibbonPanel MakePanel(string title, string[][] items)
        {
            RibbonPanelSource src = new RibbonPanelSource();
            src.Title = title;
            RibbonRowPanel smallRows = null;
            for (int i = 0; i < items.Length; i++)
            {
                bool large = items[i][3] == "L";
                if (large)
                {
                    src.Items.Add(MakeBig(items[i][0], items[i][1], items[i][2]));
                }
                else
                {
                    RibbonButton b = new RibbonButton();
                    b.Text = items[i][0];
                    b.ShowText = true;
                    b.ToolTip = items[i][0];
                    b.Size = RibbonItemSize.Standard;
                    b.Orientation = System.Windows.Controls.Orientation.Horizontal;
                    BitmapImage img16 = LoadIcon("cant_" + items[i][2] + "_16.png");
                    if (img16 != null) { b.Image = img16; b.ShowImage = true; }
                    b.CommandHandler = new CmdHandler(items[i][1]);
                    if (smallRows == null)
                    {
                        smallRows = new RibbonRowPanel();
                        src.Items.Add(smallRows);
                    }
                    else
                    {
                        smallRows.Items.Add(new RibbonRowBreak());
                    }
                    smallRows.Items.Add(b);
                }
            }
            RibbonPanel panel = new RibbonPanel();
            panel.Source = src;
            return panel;
        }

        private class CmdHandler : ICommand
        {
            private readonly string _cmd;
            public CmdHandler(string cmd) { _cmd = cmd; }
            public bool CanExecute(object p) { return true; }
            public event EventHandler CanExecuteChanged { add { } remove { } }
            public void Execute(object p)
            {
                try
                {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    if (doc != null)
                        doc.SendStringToExecute("_" + _cmd + " ", true, false, true);
                }
                catch (System.Exception ex) { Log("ERROR Cmd " + _cmd + ": " + ex.Message); }
            }
        }

        private static BitmapImage LoadIcon(string name)
        {
            try
            {
                string p = Path.Combine(Path.Combine(_dir, "iconos"), name);
                if (!File.Exists(p)) return null;
                BitmapImage img = new BitmapImage();
                img.BeginInit();
                img.CacheOption = BitmapCacheOption.OnLoad;
                img.UriSource = new Uri(p, UriKind.Absolute);
                img.EndInit();
                img.Freeze();
                return img;
            }
            catch { return null; }
        }

        private static void Log(string msg)
        {
            try
            {
                File.AppendAllText(
                    Path.Combine(Path.GetTempPath(), "urbcant_ribbon.log"),
                    DateTime.Now.ToString("HH:mm:ss") + " " + msg + "\r\n");
            }
            catch { }
        }
    }
}
