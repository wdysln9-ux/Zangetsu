import 'package:flutter/material.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/metadata/synopsis_translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/anilist_markdown.dart';

class AnimeCommunityTab extends StatefulWidget {
  const AnimeCommunityTab({super.key, required this.title, required this.anilistId, required this.malId, required this.reviews});
  final String title;
  final int? anilistId, malId;
  final bool reviews;
  @override
  State<AnimeCommunityTab> createState() => _AnimeCommunityTabState();
}
class _AnimeCommunityTabState extends State<AnimeCommunityTab> {
  late Future<List<Map<String,dynamic>>> future;
  int? mediaId;
  @override
  void initState(){ super.initState(); future=load(); }
  Future<List<Map<String,dynamic>>> load() async {
    final api=sl<AniListService>().api;
    mediaId=await api.communityMediaId(anilistId:widget.anilistId,malId:widget.malId,title:widget.title);
    if(mediaId==null)return [];
    return widget.reviews?api.fetchReviews(mediaId!):api.fetchThreads(mediaId!);
  }
  @override
  Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(
    future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      final rows=s.data??[];
      if(rows.isEmpty)return Center(child:Text(mediaId==null?'Anime tidak ditemukan di AniList.':widget.reviews?'Belum ada review.':'Belum ada thread.'));
      return RefreshIndicator(onRefresh:()async{setState(()=>future=load());await future;},child:ListView.separated(
        padding:const EdgeInsets.all(14),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:10),
        itemBuilder:(context,i)=>widget.reviews?_ReviewCard(data:rows[i],anime:widget.title):_ThreadCard(data:rows[i],anime:widget.title)));
    });
}

class _ReviewCard extends StatelessWidget{
 const _ReviewCard({required this.data,required this.anime});
 final Map<String,dynamic> data; final String anime;
 @override Widget build(BuildContext context){
  final u=data['user'] as Map? ?? {}; final av=u['avatar'] as Map? ?? {};
  final rating=(data['rating'] as num?)?.toInt()??0, amount=(data['ratingAmount'] as num?)?.toInt()??0;
  final liked=((rating.clamp(0,100)*amount)/100).round();
  return _Card(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_ReviewPage(data:data,anime:anime))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   _User(name:'${u['name']??'AniList user'}',avatar:av['large']?.toString()),const SizedBox(height:10),
   Text('${data['summary']??'Review'}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),const SizedBox(height:8),
   _Chip('$liked out of $amount users liked this review')
  ]));
 }
}
class _ThreadCard extends StatelessWidget{
 const _ThreadCard({required this.data,required this.anime}); final Map<String,dynamic> data; final String anime;
 @override Widget build(BuildContext context){
  final u=data['user'] as Map? ?? {}; final av=u['avatar'] as Map? ?? {};
  return _Card(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_ThreadPage(data:data,anime:anime))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   _User(name:'${u['name']??'AniList user'}',avatar:av['large']?.toString()),const SizedBox(height:9),
   Text('${data['title']??'Untitled thread'}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),const SizedBox(height:8),
   _Stats(views:data['viewCount'],likes:data['likeCount'],comments:data['replyCount'])
  ]));
 }
}
class _ReviewPage extends StatelessWidget{
 const _ReviewPage({required this.data,required this.anime}); final Map<String,dynamic> data; final String anime;
 @override Widget build(BuildContext context){
  final u=data['user'] as Map? ?? {}; final av=u['avatar'] as Map? ?? {};
  final rating=(data['rating'] as num?)?.toInt()??0, amount=(data['ratingAmount'] as num?)?.toInt()??0;
  final liked=((rating.clamp(0,100)*amount)/100).round();
  return Scaffold(appBar:AppBar(title:const Text('Review')),body:ListView(padding:const EdgeInsets.all(16),children:[
   Text(anime,style:TextStyle(color:AppColors.textSecondary)),const SizedBox(height:14),
   _User(name:'${u['name']??'AniList user'}',avatar:av['large']?.toString()),const SizedBox(height:14),
   Text('${data['summary']??'Review'}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:12),
   _Chip('$liked out of $amount users liked this review'),
   const SizedBox(height:20),_TranslatedMarkdown(text:'${data['body']??''}')
  ]));
 }
}
class _ThreadPage extends StatelessWidget{
 const _ThreadPage({required this.data,required this.anime}); final Map<String,dynamic> data; final String anime;
 @override Widget build(BuildContext context){
  final id=(data['id'] as num?)?.toInt();
  return Scaffold(appBar:AppBar(title:const Text('Thread')),body:id==null?const Center(child:Text('Thread tidak tersedia.')):
   FutureBuilder<Map<String,dynamic>?>(future:sl<AniListService>().api.fetchThread(id),builder:(context,s){
    final d=s.data??data; final u=d['user'] as Map? ?? {}; final av=u['avatar'] as Map? ?? {};
    final comments=d['comments'] is List?d['comments'] as List:[];
    return ListView(padding:const EdgeInsets.all(14),children:[
     Text(anime,style:TextStyle(color:AppColors.textSecondary)),const SizedBox(height:12),
     _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _User(name:'${u['name']??'AniList user'}',avatar:av['large']?.toString()),const SizedBox(height:12),
      Text('${d['title']??''}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:12),
      if(s.connectionState==ConnectionState.waiting)const LinearProgressIndicator(),
      _TranslatedMarkdown(text:'${d['body']??''}'),const SizedBox(height:14),
      _Stats(views:d['viewCount'],likes:d['likeCount'],comments:d['replyCount'])
     ])),const SizedBox(height:18),
     Text('Komentar (${d['replyCount']??comments.length})',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
     if(comments.isEmpty)const Text('Belum ada komentar.'),
     for(final c in comments)if(c is Map)_Comment(data:c)
    ]);
   }));
 }
}
class _Comment extends StatelessWidget{
 const _Comment({required this.data}); final Map data;
 @override Widget build(BuildContext context){final u=data['user'] as Map? ?? {};final av=u['avatar'] as Map? ?? {};
 return Padding(padding:const EdgeInsets.only(bottom:9),child:_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  _User(name:'${u['name']??'AniList user'}',avatar:av['large']?.toString()),const SizedBox(height:8),
  _TranslatedMarkdown(text:'${data['comment']??''}'),const SizedBox(height:8),Text('♡ ${data['likeCount']??0}',style:TextStyle(color:AppColors.textSecondary,fontSize:12))
 ])));
 }
}
class _TranslatedMarkdown extends StatefulWidget{
 const _TranslatedMarkdown({required this.text});final String text;
 @override State<_TranslatedMarkdown> createState()=>_TranslatedMarkdownState();
}
class _TranslatedMarkdownState extends State<_TranslatedMarkdown>{
 String? translated;
 @override void initState(){super.initState();_go();}
 @override void didUpdateWidget(covariant _TranslatedMarkdown old){super.didUpdateWidget(old);if(old.text!=widget.text)_go();}
 Future<void> _go()async{final t=await SynopsisTranslator.instance.translateTextToIndonesian(widget.text);if(mounted)setState(()=>translated=t);}
 @override Widget build(BuildContext context)=>AniListMarkdown(data:translated??widget.text);
}
class _Card extends StatelessWidget{
 const _Card({required this.child,this.onTap});final Widget child;final VoidCallback? onTap;
 @override Widget build(BuildContext context)=>Material(color:AppColors.surface2,borderRadius:BorderRadius.circular(14),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.all(14),child:child)));
}
class _User extends StatelessWidget{
 const _User({required this.name,this.avatar});final String name;final String? avatar;
 @override Widget build(BuildContext context)=>Row(children:[
  CircleAvatar(radius:16,backgroundImage:avatar==null||avatar!.isEmpty?null:NetworkImage(avatar!),child:avatar==null||avatar!.isEmpty?const Icon(Icons.person,size:18):null),
  const SizedBox(width:9),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w600)))
 ]);
}
class _Chip extends StatelessWidget{
 const _Chip(this.text);final String text;
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:AppColors.accent.withValues(alpha:.14),borderRadius:BorderRadius.circular(20)),child:Text(text,style:TextStyle(color:AppColors.accent,fontSize:12,fontWeight:FontWeight.w600)));
}
class _Stats extends StatelessWidget{
 const _Stats({this.views,this.likes,this.comments});final Object? views,likes,comments;
 @override Widget build(BuildContext context)=>Wrap(spacing:16,children:[
  _stat(Icons.visibility_outlined,'${views??0} views'),_stat(Icons.favorite_border,'${likes??0} likes'),_stat(Icons.mode_comment_outlined,'${comments??0} comments')
 ]);
 Widget _stat(IconData icon,String text)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:15,color:AppColors.textSecondary),const SizedBox(width:4),Text(text,style:TextStyle(fontSize:12,color:AppColors.textSecondary))]);
}
