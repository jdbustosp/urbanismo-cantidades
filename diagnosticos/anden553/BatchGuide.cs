using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.ApplicationServices;
public class BatchGuideResearch {
 static void Guard(){
  if(!String.Equals(Application.DocumentManager.MdiActiveDocument.Name,
   @"C:\Users\juanbusper\Documents\URBANISMO\work\anden_three_options\fixture.dwg",StringComparison.OrdinalIgnoreCase))
   throw new System.Exception("Solo laboratorio");
 }
 static double Num(TypedValue[] v, ref int i){return Convert.ToDouble(v[i++].Value);}
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
 [LispFunction("BNAPPEND")]
 public static int Append(ResultBuffer args){
  Guard();var v=args.AsArray();int i=0;
  string name=(string)v[i++].Value,parent=(string)v[i++].Value,layer=(string)v[i++].Value;
  var db=Application.DocumentManager.MdiActiveDocument.Database;int count=0;
  using(var tr=db.TransactionManager.StartTransaction()){
   var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
   var block=(BlockTableRecord)tr.GetObject(bt[name],OpenMode.ForWrite);
   while(i<v.Length){
    if(v[i].TypeCode==(int)LispDataType.ListBegin||v[i].TypeCode==(int)LispDataType.ListEnd){i++;continue;}
    int kind=(int)Num(v,ref i);short color=(short)Num(v,ref i);Entity e;
    if(kind==4){var p=new Polyline(4);for(int k=0;k<4;k++){
      double x=Num(v,ref i),y=Num(v,ref i),b=Num(v,ref i);p.AddVertexAt(k,new Point2d(x,y),b,0,0);}
      p.Closed=true;e=p;
    }else if(kind==2){double x=Num(v,ref i),y=Num(v,ref i),xx=Num(v,ref i),yy=Num(v,ref i);
      e=new Line(new Point3d(x,y,0),new Point3d(xx,yy,0));
    }else throw new System.Exception("Tipo geometrico inesperado");
    e.Layer=layer;e.ColorIndex=color;
    block.AppendEntity(e);tr.AddNewlyCreatedDBObject(e,true);
    using(var xd=new ResultBuffer(new TypedValue(1001,"URB_ANDEN_GEN"),new TypedValue(1000,parent),
      new TypedValue(1000,kind==4?"FEATURE_SYMBOL":"FEATURE"))){e.XData=xd;}
    count++;
   }
   Sort(block,tr);tr.Commit();
  }
  return count;
 }
 [LispFunction("BNSORT")]
 public static int Order(ResultBuffer args){
  Guard();var db=Application.DocumentManager.MdiActiveDocument.Database;
  using(var tr=db.TransactionManager.StartTransaction()){
   var bt=(BlockTable)tr.GetObject(db.BlockTableId,OpenMode.ForRead);
   var block=(BlockTableRecord)tr.GetObject(bt[(string)args.AsArray()[0].Value],OpenMode.ForRead);
   Sort(block,tr);tr.Commit();
  }return 1;
 }
}
