// Laboratory only. Not installed as part of the product.
using System;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.Civil.DatabaseServices;
public class TestSurface5715 {
  [CommandMethod("TESTSURFACE5715")]
  public static void Create() {
    var doc = Application.DocumentManager.MdiActiveDocument;
    if (!String.Equals(doc.Name, @"C:\Users\juanbusper\Documents\URBANISMO\work\tierras5715\fixture.dwg", StringComparison.OrdinalIgnoreCase))
      throw new System.Exception("Local fixture only");
    using (var tr = doc.Database.TransactionManager.StartTransaction()) {
      var id = TinSurface.Create(doc.Database, "SUP_TN");
      var surface = (TinSurface)tr.GetObject(id, OpenMode.ForWrite);
      surface.AddVertices(new Point3dCollection(new [] {
        new Point3d(80000,88000,2600), new Point3d(91000,88000,2600),
        new Point3d(91000,98000,2600), new Point3d(80000,98000,2600)}));
      surface.Rebuild();
      tr.Commit();
    }
  }
}
