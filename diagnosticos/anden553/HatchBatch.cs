using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.ApplicationServices;
public class HatchBatchResearch {
 [LispFunction("LABHATCHES")]
 public static ResultBuffer Make(ResultBuffer args) {
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!String.Equals(doc.Name,@"C:\Users\juanbusper\Documents\URBANISMO\work\anden_three_options\fixture.dwg",StringComparison.OrdinalIgnoreCase)) throw new System.Exception("Solo laboratorio");
  var v=args.AsArray(); var ids=new List<ObjectId>();
  foreach(var tv in v) if(tv.TypeCode==(int)LispDataType.Text) ids.Add(doc.Database.GetObjectId(false,new Handle(Convert.ToInt64((string)tv.Value,16)),0));
  var result=new ResultBuffer();
  using(var tr=doc.Database.TransactionManager.StartTransaction()) {
   var space=(BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId,OpenMode.ForWrite);
   foreach(var id in ids) {
    for(int k=0;k<3;k++) {
     var h=new Hatch();space.AppendEntity(h);tr.AddNewlyCreatedDBObject(h,true);
     h.Layer="URB-ANDEN-BLOQUE-BLANCO-20X10";h.ColorIndex=(short)(k==0?7:8);h.Associative=false;
     if(k==0) h.SetHatchPattern(HatchPatternType.PreDefined,"SOLID");
     else {
      h.SetHatchPattern(HatchPatternType.UserDefined,"USER");
      h.PatternDouble=false;h.PatternSpace=k==1?0.10:0.20;h.PatternAngle=0.317+(k==2?Math.PI/2:0);
      h.SetHatchPattern(HatchPatternType.UserDefined,"USER");
      h.Origin=new Point2d(82800,102400);
     }
     h.AppendLoop(HatchLoopTypes.External,new ObjectIdCollection(new ObjectId[]{id}));
     h.EvaluateHatch(true);
     result.Add(new TypedValue((int)LispDataType.ObjectId,h.ObjectId));
    }
   }
   tr.Commit();
  }
  return result;
 }
}
