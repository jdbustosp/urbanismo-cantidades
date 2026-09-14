using System;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
public class CheckBatchResearch {
 static int Rank(string s){switch(s){case "FILL":case "RELLENO":return 0;case "JOINT":return 2;case "FEATURE_FILL":return 3;case "FEATURE":case "INTERIOR":case "EXTERIOR":case "REMATE":return 4;case "FEATURE_SYMBOL":return 5;default:return 1;}}
 [LispFunction("BNCHECKORDER")]
 public static int Check(ResultBuffer args){
  var doc=Application.DocumentManager.MdiActiveDocument;
  if(!String.Equals(doc.Name,@"C:\Users\juanbusper\Documents\URBANISMO\work\anden_batchnet\fixture.dwg",StringComparison.OrdinalIgnoreCase))throw new System.Exception("Solo laboratorio");
  int errors=0,prev=-1;
  using(var tr=doc.Database.TransactionManager.StartTransaction()){
   var bt=(BlockTable)tr.GetObject(doc.Database.BlockTableId,OpenMode.ForRead);
   var b=(BlockTableRecord)tr.GetObject(bt[(string)args.AsArray()[0].Value],OpenMode.ForRead);
   var table=(DrawOrderTable)tr.GetObject(b.DrawOrderTableId,OpenMode.ForRead);
   foreach(ObjectId id in table.GetFullDrawOrder(0)){
    var e=tr.GetObject(id,OpenMode.ForRead) as Entity;
    if(e==null||e is AttributeDefinition)continue;
    string role="";using(var xd=e.GetXDataForApplication("URB_ANDEN_GEN")){
     if(xd!=null){var a=xd.AsArray();if(a.Length>=3)role=Convert.ToString(a[2].Value);}}
    int rank=Rank(role);if(rank<prev)errors++;prev=rank;
   }
  }return errors;
 }
}
