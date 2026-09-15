using System; using System.IO; using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime; using Autodesk.AutoCAD.DatabaseServices; using Autodesk.AutoCAD.ApplicationServices;
public class ReadBlocks {
 [LispFunction("OVBLOCKS")] public static int Read(ResultBuffer args) {
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!doc.Name.EndsWith(@"over559\fixture.dwg",StringComparison.OrdinalIgnoreCase))throw new System.Exception("Lab only");
  var ids=new ObjectIdCollection();var log=new List<string>();
  using(var db=new Database(false,true)) {
   db.ReadDwgFile((string)args.AsArray()[0].Value,FileOpenMode.OpenForReadAndAllShare,true,"");db.CloseInput(true);
   using(var tr=db.TransactionManager.StartTransaction()) {
    var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
    var ms=(BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace],OpenMode.ForRead);
    foreach(ObjectId id in ms){var e=(Entity)tr.GetObject(id,OpenMode.ForRead);if(e is BlockReference && (e.Layer=="URB-ANDEN"||e.Layer=="URB-ZONA-VERDE"))ids.Add(id);}
    tr.Commit();
   }
   var map=new IdMapping();db.WblockCloneObjects(ids,doc.Database.CurrentSpaceId,map,DuplicateRecordCloning.Ignore,false);
   foreach(IdPair p in map)if(p.IsPrimary)log.Add("MAPBLOCK "+p.Key.Handle+" -> "+p.Value.Handle);
  }
  File.WriteAllLines(@"C:\Users\juanbusper\Documents\ChatGPT\COMPLEMENTO AUTOCAD\work\over559\blocks.txt",log);return ids.Count;
 }
}
