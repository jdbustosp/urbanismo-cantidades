using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.ApplicationServices;
// Flat final block; exact entities, no substitute textures or quantity changes.
public class UrbAndenFast {
 [LispFunction("URBANDENFASTVERSION553")]
 public static int Version(ResultBuffer args) { return 553; }
 static int Rank(string role){
  switch(role){case "FILL":case "RELLENO":return 0;case "JOINT":return 2;
   case "FEATURE_FILL":return 3;case "FEATURE":case "INTERIOR":case "EXTERIOR":case "REMATE":return 4;
   case "FEATURE_SYMBOL":return 5;default:return 1;}
 }
 static void Sort(BlockTableRecord block,Transaction tr){
  var groups=new List<ObjectId>[6];for(int i=0;i<6;i++)groups[i]=new List<ObjectId>();
  foreach(ObjectId id in block){
   var ent=tr.GetObject(id,OpenMode.ForRead) as Entity;if(ent==null)continue;
   string role="";
   using(var xd=ent.GetXDataForApplication("URB_ANDEN_GEN")){
    if(xd!=null){var a=xd.AsArray();if(a.Length>=3)role=Convert.ToString(a[2].Value);}
   }
   groups[Rank(role)].Add(id);
  }
  var all=new ObjectIdCollection();foreach(var group in groups)foreach(var id in group)all.Add(id);
  var table=(DrawOrderTable)tr.GetObject(block.DrawOrderTableId,OpenMode.ForWrite);
  table.SetRelativeDrawOrder(all);
 }

 [LispFunction("URBANDENFLAT553")]
 public static int Flatten(ResultBuffer args) {
  string name=(string)args.AsArray()[0].Value;
  if(!name.StartsWith("URB_ANDEN_",StringComparison.OrdinalIgnoreCase)) throw new System.Exception("No es bloque de anden");
  var db=Application.DocumentManager.MdiActiveDocument.Database;
  int count=0;
  using(var tr=db.TransactionManager.StartTransaction()) {
   var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
   var block=(BlockTableRecord)tr.GetObject(bt[name],OpenMode.ForWrite);
   var references=new List<ObjectId>();
   foreach(ObjectId id in block) {
    var reference=tr.GetObject(id,OpenMode.ForRead) as BlockReference;
    if(reference!=null) references.Add(id);
   }
   foreach(var id in references) {
    var reference=(BlockReference)tr.GetObject(id,OpenMode.ForWrite);
    var child=(BlockTableRecord)tr.GetObject(reference.BlockTableRecord,OpenMode.ForRead);
    if(!child.Name.StartsWith("URB_GUIA_",StringComparison.OrdinalIgnoreCase) ||
       !reference.BlockTransform.IsEqualTo(Matrix3d.Identity))
      throw new System.Exception("Bloque interno inesperado: no se cambia su geometria");
    foreach(ObjectId source in child) {
     var entity=tr.GetObject(source,OpenMode.ForRead) as Entity;
     if(entity==null) continue;
     if(entity is BlockReference) throw new System.Exception("Guia contiene otro bloque");
     var clone=(Entity)entity.Clone();
     block.AppendEntity(clone);tr.AddNewlyCreatedDBObject(clone,true);count++;
    }
    reference.Erase();
   }
   Sort(block,tr);tr.Commit();
  }
  return count;
 }
}
