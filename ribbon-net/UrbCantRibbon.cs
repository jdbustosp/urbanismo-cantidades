// Pestana CANTIDADES dinamica (fase 1 .NET de Urbanismo Cantidades).
// El motor sigue siendo urbanismo_cantidades.lsp: cada boton dispara un
// comando LISP via SendStringToExecute. Este DLL solo dibuja la cinta.
//
// SINTAXIS C# 5 A PROPOSITO (sin interpolacion $"", sin ?., sin =>
// en miembros): el mismo archivo compila con el csc.exe integrado de
// Windows (.NET Framework 4.8, AutoCAD 2019-2024) y con dotnet SDK 8
// (AutoCAD 2025+). No modernizar la sintaxis sin revisar compilar_2023.
//
// Comportamiento pedido por el usuario: el panel Crear muestra un solo
// boton "Urbanismo"; al oprimirlo, los 14 simbolos de creacion aparecen
// EN EL MISMO ESPACIO del panel (con un boton para volver a compactar).
using System;
using System.Collections.Generic;
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
                ShowUrbanismoButton();

                tab.Panels.Add(MakePanel("Editar", new string[][] {
                    new string[] { "Editar", "EDITAR", "editar", "L" },
                    new string[] { "Etapas", "ETAPAS", "etapas", "L" } }));
                tab.Panels.Add(MakePanel("Cantidades", new string[][] {
                    new string[] { "Cuadro", "QCUADRO", "qcuadro", "L" },
                    new string[] { "Memoria", "QMEMORIA", "qmemoria", "L" },
                    new string[] { "Verificacion", "QVERIFICACION", "qverificacion", "L" },
                    new string[] { "Incluir/excluir", "QALCANCE", "qalcance", "S" },
                    new string[] { "CSV redes", "QCSV", "qcsv", "S" } }));
                tab.Panels.Add(MakePanel("Excel", new string[][] {
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

        // --- panel Crear dinamico -------------------------------------

        private static void ShowUrbanismoButton()
        {
            _crearSource.Items.Clear();
            RibbonButton urb = MakeButton("Urbanismo", null, "urbanismo", true);
            urb.CommandHandler = new SwapHandler(true);
            _crearSource.Items.Add(urb);
        }

        private static void ShowCreateIcons()
        {
            _crearSource.Items.Clear();

            RibbonButton back = new RibbonButton();
            back.Text = "<";
            back.ShowText = true;
            back.ShowImage = false;
            back.Size = RibbonItemSize.Large;
            back.Orientation = System.Windows.Controls.Orientation.Vertical;
            back.ToolTip = "Volver a compactar";
            back.CommandHandler = new SwapHandler(false);
            _crearSource.Items.Add(back);

            string[][] items = new string[][] {
                new string[] { "Via", "VIA", "via" },
                new string[] { "Anden", "ANDEN", "anden" },
                new string[] { "Rampa", "RAMPA", "rampa" },
                new string[] { "Zona verde", "ZONAVERDE", "zonaverde" },
                new string[] { "Prefabricado", "PREFABRICADO", "prefabricado" },
                new string[] { "Tramo sanitario", "TSANITARIO", "tsanitario" },
                new string[] { "Tramo pluvial", "TPLUVIAL", "tpluvial" },
                new string[] { "Tramo acueducto", "TACUEDUCTO", "tacueducto" },
                new string[] { "Pozo sanitario", "POZOSAN", "pozosan" },
                new string[] { "Pozo pluvial", "POZOPLU", "pozoplu" },
                new string[] { "Sumidero", "SUMIDERO", "sumidero" },
                new string[] { "Camara electrica", "CAMARA", "camara" },
                new string[] { "Accesorio acueducto", "ACCESORIO", "accesorio" },
                new string[] { "Luminaria", "LUMINARIA", "luminaria" } };

            // 14 simbolos en 2 filas de 7, solo icono (el nombre queda en
            // el tooltip) -- "los simbolos en el mismo espacio"
            RibbonRowPanel rows = new RibbonRowPanel();
            for (int i = 0; i < items.Length; i++)
            {
                if (i == 7) rows.Items.Add(new RibbonRowBreak());
                RibbonButton b = MakeButton(items[i][0], items[i][1], items[i][2], false);
                b.ShowText = false;
                rows.Items.Add(b);
            }
            _crearSource.Items.Add(rows);
        }

        private class SwapHandler : ICommand
        {
            private readonly bool _expand;
            public SwapHandler(bool expand) { _expand = expand; }
            public bool CanExecute(object p) { return true; }
            public event EventHandler CanExecuteChanged { add { } remove { } }
            public void Execute(object p)
            {
                try
                {
                    if (_expand) ShowCreateIcons();
                    else ShowUrbanismoButton();
                }
                catch (System.Exception ex) { Log("ERROR Swap: " + ex.Message); }
            }
        }

        // --- fabrica de paneles y botones -----------------------------

        private static RibbonPanel MakePanel(string title, string[][] items)
        {
            RibbonPanelSource src = new RibbonPanelSource();
            src.Title = title;
            RibbonRowPanel smallRows = null;
            for (int i = 0; i < items.Length; i++)
            {
                bool large = items[i][3] == "L";
                RibbonButton b = MakeButton(items[i][0], items[i][1], items[i][2], large);
                if (large)
                {
                    src.Items.Add(b);
                }
                else
                {
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

        private static RibbonButton MakeButton(
            string text, string command, string icon, bool large)
        {
            RibbonButton b = new RibbonButton();
            b.Text = text;
            b.ShowText = true;
            b.ToolTip = text;
            b.Size = large ? RibbonItemSize.Large : RibbonItemSize.Standard;
            b.Orientation = large
                ? System.Windows.Controls.Orientation.Vertical
                : System.Windows.Controls.Orientation.Horizontal;
            BitmapImage img16 = LoadIcon("cant_" + icon + "_16.png");
            BitmapImage img32 = LoadIcon("cant_" + icon + "_32.png");
            if (img16 != null) b.Image = img16;
            if (img32 != null) b.LargeImage = img32;
            b.ShowImage = (img16 != null || img32 != null);
            if (command != null) b.CommandHandler = new CmdHandler(command);
            return b;
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
