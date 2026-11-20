import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ExamStore.instance.init();
  runApp(const ExamApp());
}

const blue = Color(0xff0875a8);
const green = Color(0xff16813d);
const navy = Color(0xff073d62);

class ExamApp extends StatelessWidget {
  const ExamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'امتحانات',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: blue), scaffoldBackgroundColor: const Color(0xffedf3f8), fontFamily: 'Arial'),
    home: const ExamHome(),
  );
}

class ExamQuestion {
  int? id;
  String kind, text, options, answer;
  double mark;
  ExamQuestion({this.id, this.kind='نص عادي', this.text='', this.options='', this.answer='', this.mark=5});
  Map<String,Object?> toMap(int examId) => {'id':id,'exam_id':examId,'kind':kind,'text':text,'options':options,'answer':answer,'mark':mark};
  factory ExamQuestion.fromMap(Map<String,Object?> m) => ExamQuestion(id:m['id'] as int?,kind:m['kind'] as String,text:m['text'] as String,options:m['options'] as String,answer:m['answer'] as String,mark:(m['mark'] as num).toDouble());
}

class ExamStore {
  ExamStore._();
  static final instance=ExamStore._();
  Database? db;
  Future<void> init() async {
    final path=p.join(await getDatabasesPath(),'imtihanat.db');
    db=await openDatabase(path,version:1,onCreate:(d,v) async {
      await d.execute('CREATE TABLE exams(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, school TEXT, teacher TEXT, grade TEXT, subject TEXT, date TEXT, year TEXT)');
      await d.execute('CREATE TABLE questions(id INTEGER PRIMARY KEY AUTOINCREMENT, exam_id INTEGER, kind TEXT, text TEXT, options TEXT, answer TEXT, mark REAL)');
    });
  }
  Future<int> saveExam(Map<String,String> data,List<ExamQuestion> qs,{int? id}) async {
    final d=db!;
    return d.transaction((txn) async {
      int examId;
      if(id==null){examId=await txn.insert('exams',data);}
      else {examId=id;await txn.update('exams',data,where:'id=?',whereArgs:[id]);await txn.delete('questions',where:'exam_id=?',whereArgs:[id]);}
      for(final q in qs){await txn.insert('questions',q.toMap(examId)..remove('id'));}
      return examId;
    });
  }
  Future<List<Map<String,Object?>>> exams() => db!.query('exams',orderBy:'id DESC');
  Future<List<ExamQuestion>> questions(int id) async => (await db!.query('questions',where:'exam_id=?',whereArgs:[id],orderBy:'id')).map(ExamQuestion.fromMap).toList();
  Future<Map<String,Object?>?> exam(int id) async {final r=await db!.query('exams',where:'id=?',whereArgs:[id]);return r.isEmpty?null:r.first;}
  Future<void> delete(int id) async {await db!.delete('questions',where:'exam_id=?',whereArgs:[id]);await db!.delete('exams',where:'id=?',whereArgs:[id]);}
}

class ExamHome extends StatefulWidget {const ExamHome({super.key});@override State<ExamHome> createState()=>_ExamHomeState();}
class _ExamHomeState extends State<ExamHome> {
 final school=TextEditingController(text:'وزارة التربية'),teacher=TextEditingController(),grade=TextEditingController(text:'الخامس'),subject=TextEditingController(),title=TextEditingController(text:'الامتحان'),year=TextEditingController(text:'2026 - 2027'),date=TextEditingController(text:DateFormat('yyyy/MM/dd').format(DateTime.now()));
 final qs=<ExamQuestion>[]; int? currentId; String kind='نص عادي'; double fontSize=15; bool showAnswers=false;
 double get total=>qs.fold(0,(s,q)=>s+q.mark);
 @override void dispose(){for(final c in [school,teacher,grade,subject,title,year,date]){c.dispose();}super.dispose();}
 Map<String,String> data()=>{'school':school.text,'teacher':teacher.text,'grade':grade.text,'subject':subject.text,'title':title.text,'year':year.text,'date':date.text};
 Widget field(String label,TextEditingController c)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:c,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true,filled:true,fillColor:Colors.white),onChanged:(_)=>setState((){})));
 Widget card({required Widget child})=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xffd5e0ea)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.04),blurRadius:8)]),child:child);
 void addOrEdit({int? index}) async {
  final old=index==null?null:qs[index];
  final qText=TextEditingController(text:old?.text??'');
  final opts=TextEditingController(text:old?.options??'');
  final ans=TextEditingController(text:old?.answer??'');
  final mark=TextEditingController(text:(old?.mark??5).toString());
  String k=old?.kind??kind;
  final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Padding(padding:EdgeInsets.only(left:18,right:18,top:18,bottom:MediaQuery.of(ctx).viewInsets.bottom+18),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(index==null?'إضافة سؤال':'تعديل السؤال',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:blue)),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:k,decoration:const InputDecoration(labelText:'نوع السؤال',border:OutlineInputBorder()),items:['نص عادي','اختيار من متعدد','صح وخطأ','أكمل الفراغ','إجابة قصيرة','سؤال مقالي'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setSheet(()=>k=v??k)),
    const SizedBox(height:9),TextField(controller:qText,maxLines:3,decoration:const InputDecoration(labelText:'نص السؤال',border:OutlineInputBorder())),
    if(k=='اختيار من متعدد') ...[const SizedBox(height:9),TextField(controller:opts,maxLines:4,decoration:const InputDecoration(labelText:'الخيارات (كل خيار بسطر)',border:OutlineInputBorder()))],
    const SizedBox(height:9),TextField(controller:ans,decoration:const InputDecoration(labelText:'الإجابة النموذجية (للمدرس)',border:OutlineInputBorder())),
    const SizedBox(height:9),TextField(controller:mark,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'درجة السؤال',border:OutlineInputBorder())),
    const SizedBox(height:14),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ السؤال'))
  ])))));
  if(ok==true && qText.text.trim().isNotEmpty){setState((){final q=ExamQuestion(kind:k,text:qText.text.trim(),options:opts.text,answer:ans.text,mark:double.tryParse(mark.text)??0);if(index==null)qs.add(q);else qs[index]=q;});}
 }
 Future<void> save() async {if(title.text.trim().isEmpty){_msg('اكتب عنوان الامتحان');return;}currentId=await ExamStore.instance.saveExam(data(),qs,id:currentId);setState((){});_msg('تم حفظ الامتحان على الجهاز');}
 void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> openArchive() async {final list=await ExamStore.instance.exams();if(!mounted)return;showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:ListView(padding:const EdgeInsets.all(14),children:[const Text('الامتحانات المحفوظة',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),...list.map((e)=>ListTile(title:Text(e['title'] as String? ?? 'امتحان'),subtitle:Text('${e['subject']??''} — ${e['grade']??''}'),onTap:()async{final id=e['id'] as int;final loaded=await ExamStore.instance.exam(id);final q=await ExamStore.instance.questions(id);if(loaded!=null){setState((){currentId=id;school.text=loaded['school'] as String? ?? '';teacher.text=loaded['teacher'] as String? ?? '';grade.text=loaded['grade'] as String? ?? '';subject.text=loaded['subject'] as String? ?? '';title.text=loaded['title'] as String? ?? '';year.text=loaded['year'] as String? ?? '';date.text=loaded['date'] as String? ?? '';qs..clear()..addAll(q);});}if(ctx.mounted)Navigator.pop(ctx);},trailing:IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()async{await ExamStore.instance.delete(e['id'] as int);if(ctx.mounted)Navigator.pop(ctx);openArchive();}))),])));}
 Future<void> exportPdf(bool answers) async {
  final doc=pw.Document();
  doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,build:(ctx)=>[
   pw.Directionality(textDirection:pw.TextDirection.rtl,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
    pw.Text(school.text,style:pw.TextStyle(fontSize:14,fontWeight:pw.FontWeight.bold)),
    pw.Center(child:pw.Text(title.text,style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold))),
    pw.SizedBox(height:8),pw.Text('الصف: ${grade.text}     المادة: ${subject.text}     التاريخ: ${date.text}'),
    pw.Text('المدرس: ${teacher.text}     السنة الدراسية: ${year.text}'),
    pw.Divider(),
    ...qs.asMap().entries.map((e)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:8),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
      pw.Text('س${e.key+1}) ${e.value.text} (${e.value.mark} درجة)',style:pw.TextStyle(fontSize:14,fontWeight:pw.FontWeight.bold)),
      if(e.value.options.isNotEmpty)pw.Text(e.value.options),
      if(answers && e.value.answer.isNotEmpty)pw.Text('الإجابة النموذجية: ${e.value.answer}',style:const pw.TextStyle(color:PdfColors.blue)),
      if(!answers)pw.SizedBox(height:18),
    ])))
   ]))
  ]));
  await Printing.layoutPdf(onLayout:(_)=>doc.save());
 }
 Widget buildEditor(ExamQuestion q,int i)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xff379ed0),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Row(children:[Text('السؤال ${i+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),const Spacer(),Text('${q.mark} درجة',style:const TextStyle(color:Colors.white))]),
  const SizedBox(height:7),Text(q.text,style:const TextStyle(color:Colors.white)),
  Row(children:[IconButton(onPressed:()=>addOrEdit(index:i),icon:const Icon(Icons.edit,color:Colors.white)),IconButton(onPressed:()=>setState(()=>qs.removeAt(i)),icon:const Icon(Icons.delete,color:Colors.white)),const Spacer(),IconButton(onPressed:()=>setState((){if(i>0){final x=qs.removeAt(i);qs.insert(i-1,x);}}),icon:const Icon(Icons.keyboard_arrow_up,color:Colors.white)),IconButton(onPressed:()=>setState((){if(i<qs.length-1){final x=qs.removeAt(i);qs.insert(i+1,x);}}),icon:const Icon(Icons.keyboard_arrow_down,color:Colors.white))])
 ]));
 @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Column(children:[
  Container(color:blue,padding:const EdgeInsets.symmetric(horizontal:8,vertical:9),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
   const Padding(padding:EdgeInsets.all(8),child:Text('✍ امتحانات',style:TextStyle(color:Colors.amber,fontWeight:FontWeight.bold,fontSize:21))),
   _top('حفظ 💾',green,save),_top('طباعة',navy,()=>exportPdf(false)),_top('PDF للمدرس',navy,()=>exportPdf(true)),_top('فتح 📂',navy,openArchive),_top('＋ سؤال',navy,()=>addOrEdit()),_top('−A',navy,()=>setState(()=>fontSize=(fontSize-1).clamp(12,22).toDouble())),_top('+A',navy,()=>setState(()=>fontSize=(fontSize+1).clamp(12,22).toDouble()))
  ]))),
  Expanded(child:LayoutBuilder(builder:(ctx,c)=>c.maxWidth>850?Row(children:[Expanded(child:_preview()),SizedBox(width:430,child:_editor())]):Column(children:[Expanded(child:_editor()),Expanded(child:_preview())])))
 ])));
 Widget _top(String text,Color color,VoidCallback onTap)=>Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:FilledButton(style:FilledButton.styleFrom(backgroundColor:color,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:14,vertical:12)),onPressed:onTap,child:Text(text)));
 Widget _preview()=>Container(color:const Color(0xff94a6bb),padding:const EdgeInsets.all(12),child:SingleChildScrollView(child:Center(child:Container(width:600,margin:const EdgeInsets.all(6),padding:const EdgeInsets.all(22),color:Colors.white,child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(border:Border.all(color:Colors.black,width:2)),child:DefaultTextStyle(style:TextStyle(color:Colors.black,fontSize:fontSize,fontFamily:'serif'),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text('${school.text}\nوزارة التربية',textDirection:TextDirection.rtl)),Expanded(child:Column(children:[Text(title.text,style:const TextStyle(fontWeight:FontWeight.bold)),Text(year.text)])),Expanded(child:Text('Class: ${grade.text}\nSubject: ${subject.text}\nDate: ${date.text}',textAlign:TextAlign.end))]),
  const Divider(color:Colors.black,thickness:2),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Questions'),Text('(${total()} M)')]),
  ...qs.asMap().entries.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('Q${e.key+1}                         (${e.value.mark} M)',style:const TextStyle(color:blue,fontWeight:FontWeight.bold)),Text(e.value.text),if(e.value.options.isNotEmpty)Text(e.value.options),if(showAnswers&&e.value.answer.isNotEmpty)Text('الإجابة: ${e.value.answer}',style:const TextStyle(color:blue))])))
 ])))))));
 Widget _editor()=>SingleChildScrollView(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  card(child:Column(children:[const Text('إعدادات الشكل والطباعة ⚙',style:TextStyle(color:blue,fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:10),field('اسم المدرسة',school),field('اسم المدرس',teacher)])),
  card(child:Column(children:[const Text('معلومات الامتحان ▤',style:TextStyle(color:blue,fontSize:19,fontWeight:FontWeight.bold)),field('الصف',grade),field('المادة',subject),field('عنوان الامتحان',title),field('السنة الدراسية',year),field('التاريخ',date)])),
  Row(children:[const Text('❓ الأسئلة',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const Spacer(),Text('${qs.length} سؤال · ${total()} درجة')]),
  ...qs.asMap().entries.map((e)=>buildEditor(e.value,e.key)),
  FilledButton(style:FilledButton.styleFrom(backgroundColor:green,padding:const EdgeInsets.all(17)),onPressed:()=>addOrEdit(),child:const Text('إضافة سؤال',style:TextStyle(fontSize:18)))
 ]));
}
