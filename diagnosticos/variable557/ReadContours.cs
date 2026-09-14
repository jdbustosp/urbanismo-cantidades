using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
public class ReadContours {
 [LispFunction("VCREAD")]
 public static int Read(ResultBuffer args) {
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!doc.Name.EndsWith(@"variable557\fixture.dwg",StringComparison.OrdinalIgnoreCase))throw new System.Exception("Lab only");
  var log=new List<string>(); var ids=new ObjectIdCollection();
  using(var db=new Database(false,true)) {
   db.ReadDwgFile((string)args.AsArray()[0].Value,FileOpenMode.OpenForReadAndAllShare,true,""); db.CloseInput(true);
   using(var tr=db.TransactionManager.StartTransaction()) {
    var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
    var model=(BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace],OpenMode.ForRead);
    var polys=new List<Polyline>();
    foreach(ObjectId id in model) {var p=tr.GetObject(id,OpenMode.ForRead) as Polyline;if(p!=null&&p.Closed&&p.Area>0.01)polys.Add(p);}
    var latest=polys.OrderByDescending(p=>p.Handle.Value).Take(12).ToList();
    foreach(var p in polys) {
     if(latest.Contains(p)||p.Layer.IndexOf("CICL",StringComparison.OrdinalIgnoreCase)>=0||p.Layer.IndexOf("SEND",StringComparison.OrdinalIgnoreCase)>=0||p.Layer=="URB-ANDEN") {
      ids.Add(p.ObjectId);
      var xd=p.XData;
      log.Add(p.Handle+" | "+p.Layer+" | AREA="+p.Area+" | PER="+p.Length+" | VERTS="+p.NumberOfVertices+" | "+(xd==null?"":string.Join(";",xd.AsArray().Select(x=>x.Value.ToString()).ToArray())));
     }
    }
    tr.Commit();
   }
   var map=new IdMapping();db.WblockCloneObjects(ids,doc.Database.CurrentSpaceId,map,DuplicateRecordCloning.Ignore,false);
   foreach(IdPair p in map)if(p.IsPrimary)log.Add("MAP "+p.Key.Handle+" -> "+p.Value.Handle);
  }
  File.WriteAllLines(@"C:\Users\juanbusper\Documents\ChatGPT\COMPLEMENTO AUTOCAD\work\variable557\scan.txt",log);
  return ids.Count;
 }
}
