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
using System.IO;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
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

        public void Initialize()
        {
            try
            {
                _dir = Path.GetDirectoryName(
                    System.Reflection.Assembly.GetExecutingAssembly().Location);
                Log("Initialize");
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

        public void Terminate() { }

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
            try
            {
                if (_legacyChecked) { Application.Idle -= OnIdleUnloadLegacy; return; }
                Document doc = Application.DocumentManager.MdiActiveDocument;
                if (doc == null) return;
                _legacyChecked = true;
                Application.Idle -= OnIdleUnloadLegacy;
                doc.SendStringToExecute(
                    "(if (menugroup \"CANTIDADES\") (command \"_.CUIUNLOAD\" \"CANTIDADES\"))(princ) ",
                    true, false, false);
                Log("Chequeo de partial CUIX legado enviado");
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
                // Cantidades absorbe Excel (2026-08-11 v2); incluir/excluir
                // y CSV redes salieron de la cinta (siguen por comando)
                tab.Panels.Add(MakePanel("Cantidades", new string[][] {
                    new string[] { "Cuadro", "QCUADRO", "qcuadro", "L" },
                    new string[] { "Memoria", "QMEMORIA", "qmemoria", "L" },
                    new string[] { "Verificacion", "QVERIFICACION", "qverificacion", "L" },
                    new string[] { "Exportar", "QEXCEL", "qexcel", "L" },
                    new string[] { "Actualizar", "QACTUALIZAR", "qactualizar", "L" },
                    new string[] { "Vincular", "QVINCULAR", "qvincular", "S" },
                    new string[] { "Desvincular", "QDESVINCULAR", "qdesvincular", "S" } }));
                tab.Panels.Add(MakePanel("Configuracion", new string[][] {
                    new string[] { "Perfiles", "PERFILES", "perfiles", "L" },
                    new string[] { "Ajustes", "AJUSTES", "ajustes", "L" } }));

                _built = true;
                Log("Tab construida: " + tab.Panels.Count + " paneles");
            }
            catch (System.Exception ex) { Log("ERROR BuildTab: " + ex.Message); }
        }

        // --- panel Crear dinamico (2 niveles) --------------------------

        private static void ShowCrearRoot()
        {
            _crearSource.Items.Clear();
            RibbonButton urb = MakeBig("Urbanismo", null, "urbanismo");
            urb.CommandHandler = new NavHandler("nivel1");
            _crearSource.Items.Add(urb);
        }

        private static void ShowNivel1()
        {
            _crearSource.Items.Clear();
            AddBack("root");
            AddBigCmd("Via", "VIA", "via");
            AddBigCmd("Anden", "ANDEN", "anden");
            AddBigCmd("Rampa", "RAMPA", "rampa");
            AddBigCmd("Zona verde", "ZONAVERDE", "zonaverde");
            AddBigCmd("Prefabricado", "PREFABRICADO", "prefabricado");
            AddBigNav("Red sanitaria", "sanitaria", "tsanitario");
            AddBigNav("Red pluvial", "pluvial", "tpluvial");
            AddBigNav("Acueducto", "acueducto", "tacueducto");
            AddBigNav("Media tension", "media", "mediatension");
        }

        private static void ShowSub(string which)
        {
            _crearSource.Items.Clear();
            AddBack("nivel1");
            if (which == "sanitaria")
            {
                AddBigCmd("Tramo", "TSANITARIO", "tsanitario");
                AddBigCmd("Pozo sanitario", "POZOSAN", "pozosan");
            }
            else if (which == "pluvial")
            {
                AddBigCmd("Tramo", "TPLUVIAL", "tpluvial");
                AddBigCmd("Sumidero", "SUMIDERO", "sumidero");
                AddBigCmd("Pozo", "POZOPLU", "pozoplu");
            }
            else if (which == "acueducto")
            {
                AddBigCmd("Tramo", "TACUEDUCTO", "tacueducto");
                AddBigCmd("Accesorios", "ACCESORIO", "accesorio");
            }
            else if (which == "media")
            {
                AddBigCmd("Tramo MT", "TMT", "mediatension");
                AddBigCmd("Tramo BT", "TBT", "camara");
                AddBigCmd("Alumbrado", "TAP", "luminaria");
                AddBigCmd("Camara", "CAMARA", "camara");
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
                    else if (_target == "nivel1") ShowNivel1();
                    else ShowSub(_target);
                }
                catch (System.Exception ex) { Log("ERROR Nav: " + ex.Message); }
            }
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
