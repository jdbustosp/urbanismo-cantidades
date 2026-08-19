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
#if URB_AEC_PROPERTY
using AcDb = Autodesk.AutoCAD.DatabaseServices;
using AecDb = Autodesk.Aec.DatabaseServices;
using AecPropDb = Autodesk.Aec.PropertyData.DatabaseServices;
#endif

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
#if URB_AEC_PROPERTY
                // 2026-08-13: DESHABILITADO por defecto. El desplegable
                // nativo en Propiedades crashea Civil 3D 2023 (carrera de
                // la paleta con los PropertySets, telemetria de 3 sesiones)
                // y toco tres mecanismos de disparo sin exito. La tabla se
                // maneja con QMEMORIAVIA/QMEMORIATRAMO y el boton
                // Verificacion. Para re-experimentar: variable de entorno
                // URBCANT_MEMORIAS_PROP=1 y reiniciar.
                if (Environment.GetEnvironmentVariable(
                        "URBCANT_MEMORIAS_PROP") == "1")
                    NativeMemoryPropertyService.Initialize();
                else
                    Log("Desplegable MEMORIAS en Propiedades DESHABILITADO" +
                        " (crashea con la paleta en 2023);" +
                        " use QMEMORIAVIA / QMEMORIATRAMO");
#endif
                // 2026-08-13: control por CLIC DERECHO (pedido del usuario:
                // sin escribir comandos). Con una via/tramo seleccionado,
                // clic derecho -> "Mostrar/ocultar memorias" dispara
                // QMEMORIASEL sobre la seleccion. API estable
                // (ContextMenuExtension), sin relacion con la paleta.
                AddMemoriasContextMenu();
                if (ComponentManager.Ribbon == null)
                    ComponentManager.ItemInitialized += OnItemInitialized;
                else
                    BuildTab();
                // el partial CUIX viejo (si sigue registrado en el perfil)
                // duplicaria la pestana: se descarga solo, una vez, cuando
                // haya documento activo
                Application.Idle += OnIdleUnloadLegacy;
            }
            catch (System.Exception ex) { Log("ERROR Initialize: " + ex.Message); }
        }

        public void Terminate()
        {
#if URB_AEC_PROPERTY
            NativeMemoryPropertyService.Terminate();
#endif
            if (_memoryPropertyRegistered)
            {
                ExtendedPropertyManager.RegisterExtendedProperty -=
                    OnRegisterExtendedProperty;
                _memoryPropertyRegistered = false;
            }
        }

        private static Autodesk.AutoCAD.Windows.ContextMenuExtension _memoriasMenu;

        private static void AddMemoriasContextMenu()
        {
            try
            {
                _memoriasMenu = new Autodesk.AutoCAD.Windows.ContextMenuExtension();
                _memoriasMenu.Title = "CANTIDADES";
                Autodesk.AutoCAD.Windows.MenuItem item =
                    new Autodesk.AutoCAD.Windows.MenuItem(
                        "Mostrar/ocultar memorias");
                item.Click += OnContextMemorias;
                _memoriasMenu.MenuItems.Add(item);
                Autodesk.AutoCAD.ApplicationServices.Application
                    .AddObjectContextMenuExtension(
                        Autodesk.AutoCAD.Runtime.RXObject.GetClass(
                            typeof(AcDb.BlockReference)),
                        _memoriasMenu);
                Log("Menu contextual de memorias registrado");
            }
            catch (System.Exception ex)
            {
                Log("ERROR menu contextual: " + ex.Message);
            }
        }

        private static void OnContextMemorias(object sender, EventArgs e)
        {
            try
            {
                Autodesk.AutoCAD.ApplicationServices.Document doc =
                    Application.DocumentManager.MdiActiveDocument;
                if (doc != null)
                    doc.SendStringToExecute("QMEMORIASEL ", true, false, true);
            }
            catch (System.Exception ex)
            {
                Log("ERROR clic memorias: " + ex.Message);
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
                Log("Descriptor MEMORIAS convertido a lista: " + identity);
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

        // 2026-08-18 v4.35 (pedido del usuario): el boton vuelve a llamarse
        // "Excel" (v4.33 lo habia dejado como "Presupuesto" solo); adentro
        // del desplegable esta "Presupuesto" como unico item -- ni el
        // desplegable largo de v4.31 (7 items) ni el boton sin desplegar de
        // v4.33/4.34. Ver/cambiar libro, elegir hoja y desvincular NO estan
        // aqui: viven dentro de la propia ventana de vinculacion o de la
        // ventana de gestion que abre PPTOEXPORTAR si el libro no se puede
        // abrir. El sistema Excel generico viejo sigue disponible solo por
        // comando (QEXCEL/QVINCULAR/QACTUALIZAR/QDESVINCULAR), fuera de la
        // cinta.
        private static RibbonSplitButton MakeExcelGroup()
        {
            RibbonSplitButton sb = new RibbonSplitButton();
            sb.Text = "Excel";
            sb.ShowText = true;
            sb.ToolTip = "Presupuesto y Excel";
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
            sb.Items.Add(MakeBig("Presupuesto", "PPTOEXPORTAR", "ppto"));
            // 2026-08-19 v4.41 (pedido del usuario): la VINCULACION sale
            // del flujo de exportar a su propio boton -- elegir libro,
            // hoja, elemento/red y previsualizar el presupuesto, sin
            // exportar nada.
            sb.Items.Add(MakeBig("Vinculacion", "PPTOVINCULAR", "qvincular"));
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

#if URB_AEC_PROPERTY
        // Civil 3D incluye el motor Property Data de AutoCAD Architecture.
        // Una PropertyDefinition de tipo List produce un combo NATIVO en
        // Propiedades > Datos extendidos. Es el mecanismo Autodesk soportado;
        // ExtendedPropertyManager no intercepta los atributos de bloques.
        private static class NativeMemoryPropertyService
        {
            private const string ListName = "URB_ESTADOS_MEMORIA";
            private const string SetName = "URB_MEMORIAS";
            private static AcDb.Database _database;
            private static readonly System.Collections.Generic.HashSet<AcDb.ObjectId>
                PendingBlocks = new System.Collections.Generic.HashSet<AcDb.ObjectId>();
            private static readonly System.Collections.Generic.HashSet<AcDb.ObjectId>
                PendingSets = new System.Collections.Generic.HashSet<AcDb.ObjectId>();
            private static readonly System.Collections.Generic.HashSet<AcDb.ObjectId>
                TrackedBlocks = new System.Collections.Generic.HashSet<AcDb.ObjectId>();
            private static readonly System.Collections.Generic.HashSet<AcDb.ObjectId>
                TrackedSets = new System.Collections.Generic.HashSet<AcDb.ObjectId>();
            private static readonly System.Collections.Generic.Dictionary<AcDb.ObjectId, string>
                LastPropertyStates = new System.Collections.Generic.Dictionary<AcDb.ObjectId, string>();
            private static readonly System.Collections.Generic.Dictionary<AcDb.ObjectId, string>
                LastAttributeStates = new System.Collections.Generic.Dictionary<AcDb.ObjectId, string>();
            private static bool _scanPending;
            private static bool _busy;
            // 2026-08-13: cuando el cambio de estado nace en el desplegable
            // de Propiedades, el atributo se escribe DENTRO del Idle con el
            // documento bloqueado; el vla-SendCommand que difiere el reactor
            // LISP se descarta en ese contexto (hallazgo de la sesion Codex).
            // El propio servicio dispara ACTUALIZARMEMORIAS al salir del
            // bloqueo, en contexto de comando (mecanismo soportado).
            private static bool _commandPending;
            // 2026-08-13 v2: freno + telemetria. Antes el servicio corria
            // transacciones en CADA evento Idle (que en sesion viva dispara
            // constantemente); ahora el sondeo de cambios externos corre a
            // lo sumo cada 500 ms y solo se procesa cuando hay pendientes.
            private static DateTime _lastPollRun = DateTime.MinValue;
            private static readonly System.Collections.Generic.HashSet<AcDb.ObjectId>
                WarnedOldSchema = new System.Collections.Generic.HashSet<AcDb.ObjectId>();

            public static void Initialize()
            {
                Application.Idle += OnIdle;
                _scanPending = true;
                Log("Propiedad nativa MEMORIAS programada");
            }

            public static void Terminate()
            {
                Application.Idle -= OnIdle;
                DetachDatabase();
            }

            private static void DetachDatabase()
            {
                if (_database != null)
                {
                    _database.ObjectAppended -= OnObjectAppended;
                    _database.ObjectModified -= OnObjectModified;
                }
                _database = null;
                PendingBlocks.Clear();
                PendingSets.Clear();
                TrackedBlocks.Clear();
                TrackedSets.Clear();
                LastPropertyStates.Clear();
                LastAttributeStates.Clear();
            }

            private static void AttachDatabase(AcDb.Database database)
            {
                // MdiActiveDocument.Database puede devolver otro wrapper .NET
                // para la misma base nativa. Comparar ReferenceEquals reiniciaba
                // el seguimiento en cada Idle y anulaba cambios del desplegable.
                if (_database != null && database != null &&
                    _database.UnmanagedObject == database.UnmanagedObject) return;
                DetachDatabase();
                _database = database;
                if (_database != null)
                {
                    _database.ObjectAppended += OnObjectAppended;
                    _database.ObjectModified += OnObjectModified;
                    _scanPending = true;
                }
            }

            private static void OnObjectAppended(object sender, AcDb.ObjectEventArgs e)
            {
                if (_busy || e == null || e.DBObject == null) return;
                AcDb.BlockReference block = e.DBObject as AcDb.BlockReference;
                if (block != null && !block.ObjectId.IsNull)
                    PendingBlocks.Add(block.ObjectId);
            }

            private static void OnObjectModified(object sender, AcDb.ObjectEventArgs e)
            {
                if (_busy || e == null || e.DBObject == null) return;
                AecPropDb.PropertySet set = e.DBObject as AecPropDb.PropertySet;
                if (set != null && !set.ObjectId.IsNull)
                {
                    PendingSets.Add(set.ObjectId);
                    return;
                }
                AcDb.AttributeReference attribute =
                    e.DBObject as AcDb.AttributeReference;
                if (attribute != null &&
                    string.Equals(attribute.Tag, "MEMORIAS",
                        StringComparison.OrdinalIgnoreCase) &&
                    !attribute.OwnerId.IsNull)
                    PendingBlocks.Add(attribute.OwnerId);
            }

            private static void OnIdle(object sender, EventArgs e)
            {
                if (_busy) return;
                Autodesk.AutoCAD.ApplicationServices.Document doc =
                    Application.DocumentManager.MdiActiveDocument;
                if (doc == null) return;
                AttachDatabase(doc.Database);
                try
                {
                    object commandNames = Application.GetSystemVariable("CMDNAMES");
                    if (commandNames != null && commandNames.ToString().Length > 0)
                        return;
                }
                catch { }
                // freno: sin pendientes, el sondeo de cambios externos corre
                // a lo sumo cada 500 ms (antes: transacciones en cada Idle)
                bool hasPending = _scanPending ||
                    PendingBlocks.Count > 0 || PendingSets.Count > 0;
                if (!hasPending &&
                    (DateTime.Now - _lastPollRun).TotalMilliseconds < 500)
                    return;
                _lastPollRun = DateTime.Now;
                System.Diagnostics.Stopwatch watch =
                    System.Diagnostics.Stopwatch.StartNew();
                int blockCount = 0;
                int setCount = 0;
                try
                {
                    _busy = true;
                    using (Autodesk.AutoCAD.ApplicationServices.DocumentLock
                        documentLock = doc.LockDocument())
                    {
                        if (_scanPending)
                        {
                            QueueAllBlocks(doc.Database);
                            _scanPending = false;
                        }
                        // 2026-08-13 v4: SIN sondeo periodico. Releer los
                        // PropertySets en cada pasada (QueueTrackedChanges /
                        // QueueSelectedPropertySets) chocaba con la paleta de
                        // Propiedades con el desplegable activo -> crash
                        // fatal nativo (Error Report), consistente en todas
                        // las sesiones. Los eventos ObjectModified ya
                        // encolan solos el set/bloque que cambio.
                        setCount = PendingSets.Count;
                        blockCount = PendingBlocks.Count;
                        ProcessPropertySets(doc);
                        ProcessBlocks(doc.Database);
                    }
                }
                catch (System.Exception ex)
                {
                    Log("ERROR propiedad nativa MEMORIAS: " + ex.Message);
                }
                finally { _busy = false; }
                watch.Stop();
                // telemetria: solo cuando hubo trabajo o tardo de verdad
                if (blockCount > 0 || setCount > 0 ||
                    watch.ElapsedMilliseconds > 100)
                    Log("Idle memorias: " + watch.ElapsedMilliseconds +
                        " ms (bloques " + blockCount +
                        ", sets " + setCount + ")");
                // Fuera del using (bloqueo ya liberado) y fuera de _busy:
                // aqui si se puede encolar el comando sin que se descarte.
                if (_commandPending) FireMemoryCommand(doc);
            }

            private static void FireMemoryCommand(
                Autodesk.AutoCAD.ApplicationServices.Document doc)
            {
                // 2026-08-13 v3: ExecuteInCommandContextAsync REVIENTA Civil
                // 3D 2023 (crash fatal en la transicion nativa, confirmado
                // con la telemetria: "Idle memorias ... sets 1" y ninguna
                // linea despues). El encolado clasico por linea de comandos
                // -- el MISMO camino de todos los botones de la cinta --
                // aqui se llama DESPUES de soltar el bloqueo del documento,
                // que era lo que hacia que el envio del reactor LISP se
                // descartara (aquel se emitia DURANTE la transaccion).
                _commandPending = false;
                try
                {
                    doc.SendStringToExecute(
                        "ACTUALIZARMEMORIAS ", true, false, true);
                    Log("ACTUALIZARMEMORIAS encolado por linea de comandos");
                }
                catch (System.Exception ex)
                {
                    Log("ERROR encolando ACTUALIZARMEMORIAS: " + ex.Message);
                }
            }

            private static void QueueTrackedChanges(AcDb.Database database)
            {
                using (AcDb.Transaction tr =
                    database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (AcDb.ObjectId blockId in TrackedBlocks)
                    {
                        if (!blockId.IsValid || blockId.IsErased) continue;
                        AcDb.BlockReference block = tr.GetObject(
                            blockId, AcDb.OpenMode.ForRead, false)
                            as AcDb.BlockReference;
                        AcDb.AttributeReference attribute;
                        string current;
                        string previous;
                        if (block != null &&
                            TryMemoryAttribute(block, tr, out attribute, out current) &&
                            LastAttributeStates.TryGetValue(blockId, out previous) &&
                            !string.Equals(previous, current,
                                StringComparison.OrdinalIgnoreCase))
                            PendingBlocks.Add(blockId);
                    }
                    foreach (AcDb.ObjectId setId in TrackedSets)
                    {
                        if (!setId.IsValid || setId.IsErased) continue;
                        AecPropDb.PropertySet set = tr.GetObject(
                            setId, AcDb.OpenMode.ForRead, false)
                            as AecPropDb.PropertySet;
                        if (set == null) continue;
                        string current = Convert.ToString(
                            set.GetAt(set.PropertyNameToId("MEMORIAS")));
                        string previous;
                        if (LastPropertyStates.TryGetValue(setId, out previous) &&
                            !string.Equals(previous, current,
                                StringComparison.OrdinalIgnoreCase))
                            PendingSets.Add(setId);
                    }
                    tr.Commit();
                }
            }

            private static void QueueAllBlocks(AcDb.Database database)
            {
                using (AcDb.Transaction tr =
                    database.TransactionManager.StartOpenCloseTransaction())
                {
                    AcDb.BlockTable table = (AcDb.BlockTable)tr.GetObject(
                        database.BlockTableId, AcDb.OpenMode.ForRead);
                    foreach (AcDb.ObjectId recordId in table)
                    {
                        AcDb.BlockTableRecord record =
                            (AcDb.BlockTableRecord)tr.GetObject(
                                recordId, AcDb.OpenMode.ForRead);
                        if (!record.IsLayout || record.IsFromExternalReference) continue;
                        foreach (AcDb.ObjectId id in record)
                            if (id.ObjectClass != null &&
                                id.ObjectClass.IsDerivedFrom(
                                    Autodesk.AutoCAD.Runtime.RXObject.GetClass(
                                        typeof(AcDb.BlockReference))))
                                PendingBlocks.Add(id);
                    }
                    tr.Commit();
                }
            }

            private static void QueueSelectedPropertySets(
                Autodesk.AutoCAD.ApplicationServices.Document doc)
            {
                Autodesk.AutoCAD.EditorInput.PromptSelectionResult selected =
                    doc.Editor.SelectImplied();
                if (selected.Status !=
                        Autodesk.AutoCAD.EditorInput.PromptStatus.OK ||
                    selected.Value == null) return;
                using (AcDb.Transaction tr =
                    doc.Database.TransactionManager.StartOpenCloseTransaction())
                {
                    foreach (Autodesk.AutoCAD.EditorInput.SelectedObject item in
                        selected.Value)
                    {
                        if (item == null || item.ObjectId.IsNull) continue;
                        AcDb.DBObject obj = tr.GetObject(
                            item.ObjectId, AcDb.OpenMode.ForRead, false);
                        AcDb.BlockReference selectedBlock = obj as AcDb.BlockReference;
                        if (selectedBlock != null)
                        {
                            AcDb.AttributeReference selectedAttribute;
                            string selectedState;
                            if (TryMemoryAttribute(selectedBlock, tr,
                                    out selectedAttribute, out selectedState))
                            {
                                string previousAttribute;
                                if (LastAttributeStates.TryGetValue(
                                        selectedBlock.ObjectId,
                                        out previousAttribute) &&
                                    !string.Equals(previousAttribute, selectedState,
                                        StringComparison.OrdinalIgnoreCase))
                                    PendingBlocks.Add(selectedBlock.ObjectId);
                            }
                        }
                        AcDb.ObjectIdCollection sets =
                            AecPropDb.PropertyDataServices.GetPropertySets(obj);
                        foreach (AcDb.ObjectId setId in sets)
                        {
                            if (setId.IsNull) continue;
                            AecPropDb.PropertySet set = tr.GetObject(
                                setId, AcDb.OpenMode.ForRead, false)
                                as AecPropDb.PropertySet;
                            if (set == null || !string.Equals(
                                set.PropertySetDefinitionName, SetName,
                                StringComparison.OrdinalIgnoreCase)) continue;
                            string current = Convert.ToString(
                                set.GetAt(set.PropertyNameToId("MEMORIAS")));
                            string previous;
                            if (LastPropertyStates.TryGetValue(setId, out previous) &&
                                !string.Equals(previous, current,
                                    StringComparison.OrdinalIgnoreCase))
                                PendingSets.Add(setId);
                        }
                    }
                    tr.Commit();
                }
            }

            private static bool TryMemoryAttribute(
                AcDb.BlockReference block, AcDb.Transaction tr,
                out AcDb.AttributeReference found, out string state)
            {
                found = null;
                state = "OCULTAR";
                foreach (AcDb.ObjectId id in block.AttributeCollection)
                {
                    AcDb.AttributeReference attribute = tr.GetObject(
                        id, AcDb.OpenMode.ForRead, false) as AcDb.AttributeReference;
                    if (attribute != null &&
                        string.Equals(attribute.Tag, "MEMORIAS",
                            StringComparison.OrdinalIgnoreCase))
                    {
                        found = attribute;
                        string value = (attribute.TextString ?? "").ToUpperInvariant();
                        state = (value.IndexOf("VISIB") >= 0 ||
                                 value.IndexOf("MOSTRAR") >= 0)
                            ? "MOSTRAR" : "OCULTAR";
                        return true;
                    }
                }
                return false;
            }

            private static AcDb.ObjectId EnsureDefinitions(
                AcDb.Database database, AcDb.Transaction tr)
            {
                AecDb.DictionaryListDefinition listDictionary =
                    new AecDb.DictionaryListDefinition(database);
                AcDb.ObjectId listId = listDictionary.Has(ListName, tr)
                    ? listDictionary.GetAt(ListName) : AcDb.ObjectId.Null;
                if (listId.IsNull)
                {
                    AecDb.ListDefinition list = new AecDb.ListDefinition();
                    list.SetToStandard(database);
                    list.SubSetDatabaseDefaults(database);
                    list.Description = "Estados permitidos para memorias Urbanismo";
                    list.AllowToVary = false;
                    listDictionary.AddNewRecord(ListName, list);
                    tr.AddNewlyCreatedDBObject(list, true);
                    list.AddListItem("MOSTRAR");
                    list.AddListItem("OCULTAR");
                    listId = list.ObjectId;
                }

                AecPropDb.DictionaryPropertySetDefinitions dictionary =
                    new AecPropDb.DictionaryPropertySetDefinitions(database);
                AcDb.ObjectId definitionId = dictionary.Has(SetName, tr)
                    ? dictionary.GetAt(SetName) : AcDb.ObjectId.Null;
                if (definitionId.IsNull)
                {
                    AecPropDb.PropertySetDefinition definition =
                        new AecPropDb.PropertySetDefinition();
                    definition.SetToStandard(database);
                    definition.SubSetDatabaseDefaults(database);
                    definition.Description = "Control de memorias Urbanismo";
                    definition.IsVisible = true;
                    definition.IsWriteable = true;
                    System.Collections.Specialized.StringCollection appliesTo =
                        new System.Collections.Specialized.StringCollection();
                    appliesTo.Add("AcDbBlockReference");
                    definition.SetAppliesToFilter(appliesTo, false);

                    AecPropDb.PropertyDefinition property =
                        new AecPropDb.PropertyDefinition();
                    property.SetToStandard(database);
                    property.SubSetDatabaseDefaults(database);
                    property.Name = "MEMORIAS";
                    property.Description = "Mostrar u ocultar la tabla de memorias";
                    property.DataType = Autodesk.Aec.PropertyData.DataType.List;
                    property.DefaultData = "OCULTAR";
                    property.ListDefinitionId = listId;
                    definition.Definitions.Add(property);
                    dictionary.AddNewRecord(SetName, definition);
                    tr.AddNewlyCreatedDBObject(definition, true);
                    definitionId = definition.ObjectId;
                }
                return definitionId;
            }

            private static void ProcessBlocks(AcDb.Database database)
            {
                AcDb.ObjectId[] ids = new AcDb.ObjectId[PendingBlocks.Count];
                PendingBlocks.CopyTo(ids);
                PendingBlocks.Clear();
                foreach (AcDb.ObjectId id in ids)
                {
                    if (!id.IsValid || id.IsErased) continue;
                    using (AcDb.Transaction tr =
                        database.TransactionManager.StartTransaction())
                    {
                        AcDb.BlockReference block = tr.GetObject(
                            id, AcDb.OpenMode.ForRead, false) as AcDb.BlockReference;
                        if (block == null) continue;
                        AcDb.AttributeReference attribute;
                        string state;
                        if (!TryMemoryAttribute(block, tr, out attribute, out state))
                            continue;
                        AcDb.ObjectId definitionId = EnsureDefinitions(database, tr);
                        AcDb.ObjectId setId = AcDb.ObjectId.Null;
                        try
                        {
                            setId = AecPropDb.PropertyDataServices.GetPropertySet(
                                block, definitionId);
                        }
                        catch (Autodesk.AutoCAD.Runtime.Exception ex)
                        {
                            if (ex.ErrorStatus != ErrorStatus.KeyNotFound) throw;
                        }
                        if (setId.IsNull)
                        {
                            block.UpgradeOpen();
                            AecPropDb.PropertyDataServices.AddPropertySet(
                                block, definitionId);
                            setId = AecPropDb.PropertyDataServices.GetPropertySet(
                                block, definitionId);
                        }
                        AecPropDb.PropertySet set = (AecPropDb.PropertySet)tr.GetObject(
                            setId, AcDb.OpenMode.ForWrite);
                        int propertyId = set.PropertyNameToId("MEMORIAS");
                        object current = set.GetAt(propertyId);
                        if (!string.Equals(Convert.ToString(current), state,
                                StringComparison.OrdinalIgnoreCase))
                            set.SetAt(propertyId, state);
                        LastPropertyStates[setId] = state;
                        LastAttributeStates[id] = state;
                        TrackedBlocks.Add(id);
                        TrackedSets.Add(setId);
                        tr.Commit();
                    }
                }
            }

            private static void ProcessPropertySets(
                Autodesk.AutoCAD.ApplicationServices.Document doc)
            {
                AcDb.ObjectId[] ids = new AcDb.ObjectId[PendingSets.Count];
                PendingSets.CopyTo(ids);
                PendingSets.Clear();
                foreach (AcDb.ObjectId id in ids)
                {
                    if (!id.IsValid || id.IsErased) continue;
                    using (AcDb.Transaction tr =
                        doc.Database.TransactionManager.StartTransaction())
                    {
                        AecPropDb.PropertySet set = tr.GetObject(
                            id, AcDb.OpenMode.ForRead, false) as AecPropDb.PropertySet;
                        if (set == null || !string.Equals(
                            set.PropertySetDefinitionName, SetName,
                            StringComparison.OrdinalIgnoreCase)) continue;
                        string state = Convert.ToString(
                            set.GetAt(set.PropertyNameToId("MEMORIAS")));
                        state = string.Equals(state, "MOSTRAR",
                            StringComparison.OrdinalIgnoreCase)
                            ? "MOSTRAR" : "OCULTAR";
                        LastPropertyStates[id] = state;
                        TrackedSets.Add(id);
                        AcDb.BlockReference block = tr.GetObject(
                            set.ObjectAttachedTo, AcDb.OpenMode.ForRead, false)
                            as AcDb.BlockReference;
                        if (block != null)
                        {
                            AcDb.AttributeReference attribute;
                            string oldState;
                            if (TryMemoryAttribute(block, tr, out attribute, out oldState))
                            {
                                if (!string.Equals(oldState, state,
                                        StringComparison.OrdinalIgnoreCase))
                                {
                                    attribute.UpgradeOpen();
                                    attribute.TextString = state;
                                    // el reactor LISP encola el pedido pero
                                    // su SendCommand se pierde en este
                                    // contexto: el servicio dispara el
                                    // comando al salir del bloqueo
                                    _commandPending = true;
                                }
                            }
                            else if (WarnedOldSchema.Add(block.ObjectId))
                            {
                                // via/tramo de esquema viejo: el bloque no
                                // tiene el atributo MEMORIAS y el cambio del
                                // desplegable no tiene donde aterrizar
                                Log("Bloque sin atributo MEMORIAS (esquema " +
                                    "viejo): pase EDITAR a esa via/tramo " +
                                    "para actualizarla");
                            }
                            LastAttributeStates[block.ObjectId] = state;
                            TrackedBlocks.Add(block.ObjectId);
                        }
                        tr.Commit();
                    }
                }
            }
        }
#endif
    }
}
