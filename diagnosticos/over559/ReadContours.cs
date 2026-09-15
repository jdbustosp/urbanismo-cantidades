using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
public class ReadOver {
 [LispFunction("OVREAD")]
 public static int Read(ResultBuffer args) {
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!doc.Name.EndsWith(@"over559\fixture.dwg",StringComparison.OrdinalIgnoreCase))throw new System.Exception("Lab only");
  var log=new List<string>(); var ids=new ObjectIdCollection();
  using(var db=new Database(false,true)) {
   db.ReadDwgFile((string)args.AsArray()[0].Value,FileOpenMode.OpenForReadAndAllShare,true,""); db.CloseInput(true);
   using(var tr=db.TransactionManager.StartTransaction()) {
    var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
    var model=(BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace],OpenMode.ForRead);
    var polys=new List<Polyline>();
    foreach(ObjectId id in model) {
     var e=(Entity)tr.GetObject(id,OpenMode.ForRead);var p=e as Polyline;
     if(p!=null&&p.Closed&&p.Area>0.01)polys.Add(p);
     var b=e as BlockReference;
     if(b!=null&&(b.Layer=="URB-ANDEN"||b.Layer=="URB-ZONA-VERDE")) {
      log.Add("BLOCK "+b.Handle+" | "+b.Layer+" | "+b.Position+" | "+((BlockTableRecord)tr.GetObject(b.BlockTableRecord,OpenMode.ForRead)).Name);
      foreach(ObjectId a in b.AttributeCollection){var at=(AttributeReference)tr.GetObject(a,OpenMode.ForRead);log.Add(" ATTR "+at.Tag+"="+at.TextString);}
     }
    }
    var latest=polys.OrderByDescending(p=>p.Handle.Value).Take(16).ToList();
    foreach(var p in polys) {
     if(latest.Contains(p)||p.Layer=="URB-ANDEN") {
      ids.Add(p.ObjectId);
      log.Add("POLY "+p.Handle+" | "+p.Layer+" | AREA="+p.Area+" | PER="+p.Length+" | VERTS="+p.NumberOfVertices+" | BBOX="+p.GeometricExtents);
     }
    }
    tr.Commit();
   }
   var map=new IdMapping();db.WblockCloneObjects(ids,doc.Database.CurrentSpaceId,map,DuplicateRecordCloning.Ignore,false);
   foreach(IdPair p in map)if(p.IsPrimary)log.Add("MAP "+p.Key.Handle+" -> "+p.Value.Handle);
  }
  File.WriteAllLines(@"C:\Users\juanbusper\Documents\ChatGPT\COMPLEMENTO AUTOCAD\work\over559\scan.txt",log);
  return ids.Count;
 }
}
