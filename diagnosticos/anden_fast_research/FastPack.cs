// Prototipo aislado, Civil 3D 2023. No se instala.
using System;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.ApplicationServices;
public class FastPackResearch {
 [LispFunction("FRPACK")]
 public static int Pack(ResultBuffer args) {
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!String.Equals(doc.Name,@"C:\Users\juanbusper\Documents\URBANISMO\work\anden_fast_research\fixture.dwg",StringComparison.OrdinalIgnoreCase))
    throw new System.Exception("Solo laboratorio");
  var values=args.AsArray(); var name=(string)values[0].Value;
  var selection=(SelectionSet)values[1].Value;
  var ids=new ObjectIdCollection(selection.GetObjectIds());
  // No abrir las entidades ForWrite antes de AssumeOwnershipOf:
  // Autodesk advierte que hacerlo puede terminar AutoCAD.
  using(var tr=doc.Database.TransactionManager.StartTransaction()) {
    var bt=(BlockTable)tr.GetObject(doc.Database.BlockTableId,OpenMode.ForWrite);
    if(bt.Has(name)) throw new System.Exception("Nombre duplicado");
    var block=new BlockTableRecord {Name=name,Origin=Point3d.Origin};
    bt.Add(block); tr.AddNewlyCreatedDBObject(block,true);
    block.AssumeOwnershipOf(ids);
    tr.Commit();
  }
  return ids.Count;
 }
}
