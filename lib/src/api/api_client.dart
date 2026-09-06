import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../models/support_models.dart';

class ApiClient {
  ApiClient._(this.dio,this.cookieJar);
  static const origin='https://arofi.net';
  static const apiBase='$origin/api';
  final Dio dio; final PersistCookieJar cookieJar; Future<void>? _refreshFuture;

  static Future<ApiClient> create() async {
    final dir=await getApplicationSupportDirectory();
    final jar=PersistCookieJar(ignoreExpires:false,storage:FileStorage('${dir.path}${Platform.pathSeparator}cookies'));
    final dio=Dio(BaseOptions(baseUrl:apiBase,connectTimeout:const Duration(seconds:20),sendTimeout:const Duration(seconds:45),receiveTimeout:const Duration(seconds:45),headers:const {'Accept':'application/json'},validateStatus:(s)=>s!=null&&s>=200&&s<500));
    final api=ApiClient._(dio,jar); dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(InterceptorsWrapper(onResponse:(response,handler) async {if(response.statusCode==401&&response.requestOptions.extra['retried']!=true){final path=response.requestOptions.path;final auth=path.contains('/auth/login')||path.contains('/auth/refresh');if(!auth&&await api._refresh()){try{final req=response.requestOptions;req.extra['retried']=true;return handler.resolve(await dio.fetch<dynamic>(req));}catch(_){}}}handler.next(response);}));
    return api;
  }

  Future<bool> _refresh() async {if(_refreshFuture!=null){try{await _refreshFuture;}catch(_){} return true;}final c=Completer<void>();_refreshFuture=c.future;try{final r=await dio.post<dynamic>('/auth/refresh',options:Options(extra:{'retried':true}));if(r.statusCode==200){c.complete();return true;}c.completeError(StateError('Session refresh failed'));return false;}catch(e,s){if(!c.isCompleted)c.completeError(e,s);return false;}finally{_refreshFuture=null;}}
  Never _throw(Response<dynamic> r,[String fallback='Request failed']){final d=r.data;var m=fallback;if(d is Map<String,dynamic>){final raw=d['message'];if(raw is String&&raw.trim().isNotEmpty)m=raw;if(raw is List&&raw.isNotEmpty)m=raw.first.toString();}throw ApiException(m,r.statusCode??0);}
  Future<Map<String,dynamic>> loginStart(String email,String password) async {final r=await dio.post<dynamic>('/auth/login/start',data:{'email':email.trim(),'password':password});if(r.statusCode!=200&&r.statusCode!=201)_throw(r,'Sign in failed');return Map<String,dynamic>.from(r.data as Map);}
  Future<void> verifyOtp(String email,String otp,{bool rememberDevice=true}) async {final r=await dio.post<dynamic>('/auth/login/verify',data:{'email':email.trim(),'otp':otp.trim(),'rememberDevice':rememberDevice});if(r.statusCode!=200&&r.statusCode!=201)_throw(r,'Verification failed');}
  Future<void> resendOtp(String email) async {final r=await dio.post<dynamic>('/auth/login/resend',data:{'email':email.trim()});if(r.statusCode!=200&&r.statusCode!=201)_throw(r,'Could not resend code');}
  Future<SupportUser?> getMe() async {final r=await dio.get<dynamic>('/auth/me');if(r.statusCode==401)return null;if(r.statusCode!=200)_throw(r,'Could not load account');final d=Map<String,dynamic>.from(r.data as Map),u=d['user'];return u is Map<String,dynamic>?SupportUser.fromJson(u):null;}
  Future<void> logout() async {try{await dio.post<dynamic>('/auth/logout');}finally{await cookieJar.deleteAll();}}
  Future<List<SupportTicket>> loadTickets() async {final r=await dio.get<dynamic>('/support-floor/tickets');if(r.statusCode!=200)_throw(r,'Could not load support inbox');final d=Map<String,dynamic>.from(r.data as Map);final items=(d['items'] as List<dynamic>? ?? const []).whereType<Map<String,dynamic>>().map(SupportTicket.fromJson).toList();items.sort((a,b)=>b.sortTime.compareTo(a.sortTime));return items;}
  Future<List<SupportAgent>> loadStaff() async {final r=await dio.get<dynamic>('/support-floor/staff');if(r.statusCode!=200)_throw(r,'Could not load support staff');final d=Map<String,dynamic>.from(r.data as Map);return (d['items'] as List<dynamic>? ?? const []).whereType<Map<String,dynamic>>().map(SupportAgent.fromJson).toList();}
  Future<SupportTicket> updateTicket(String id,{String? status,String? priority,String? assigneeUserId,bool includeAssignee=false}) async {final p=<String,dynamic>{};if(status!=null)p['status']=status;if(priority!=null)p['priority']=priority;if(includeAssignee)p['assigneeUserId']=assigneeUserId;final r=await dio.patch<dynamic>('/support-floor/tickets/$id',data:p);if(r.statusCode!=200)_throw(r,'Could not update conversation');return SupportTicket.fromJson(Map<String,dynamic>.from(r.data as Map));}
  Future<SupportTicket> sendMessage(String id,String body,{bool isInternal=false,String? statusAfterReply}) async {final p=<String,dynamic>{'body':body.trim(),'isInternal':isInternal};if(statusAfterReply!=null)p['statusAfterReply']=statusAfterReply;final r=await dio.post<dynamic>('/support-floor/tickets/$id/messages',data:p);if(r.statusCode!=200&&r.statusCode!=201)_throw(r,'Could not send message');return SupportTicket.fromJson(Map<String,dynamic>.from(r.data as Map));}
  Future<SupportTicket> uploadAttachment(String id,String filePath,{String? body,bool isInternal=false,String? mimeType}) async {final fileName=filePath.split(Platform.pathSeparator).last;final form=FormData.fromMap({'file':await MultipartFile.fromFile(filePath,filename:fileName,contentType:mimeType==null?null:MediaType.parse(mimeType)),if(body!=null&&body.trim().isNotEmpty)'body':body.trim(),'isInternal':isInternal.toString()});final r=await dio.post<dynamic>('/support-floor/tickets/$id/attachments',data:form,options:Options(contentType:'multipart/form-data',sendTimeout:const Duration(minutes:2)));if(r.statusCode!=200&&r.statusCode!=201)_throw(r,'Could not upload attachment');return SupportTicket.fromJson(Map<String,dynamic>.from(r.data as Map));}
  String attachmentUrl(String id)=>'$apiBase/support-floor/attachments/$id/file';
  Future<String> cookieHeaderFor(Uri uri) async {final cookies=await cookieJar.loadForRequest(uri);return cookies.map((c)=>'${c.name}=${c.value}').join('; ');}
  Future<String> downloadAttachment(SupportAttachment a) async {final temp=await getTemporaryDirectory();final safe=a.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'),'_');final path='${temp.path}${Platform.pathSeparator}${a.id}_$safe';final r=await dio.download('/support-floor/attachments/${a.id}/file',path,options:Options(receiveTimeout:const Duration(minutes:2)));if(r.statusCode!=200)_throw(r,'Could not download attachment');return path;}
  Stream<Map<String,dynamic>> supportEvents() async* {while(true){try{final r=await dio.get<ResponseBody>('/support-floor/events',options:Options(responseType:ResponseType.stream,headers:const {'Accept':'text/event-stream','Cache-Control':'no-cache'},receiveTimeout:Duration.zero));if(r.statusCode!=200||r.data==null){await Future<void>.delayed(const Duration(seconds:2));continue;}final lines=r.data!.stream.map<List<int>>((c)=>c).transform(utf8.decoder).transform(const LineSplitter());await for(final line in lines){if(!line.startsWith('data:'))continue;final p=line.substring(5).trim();if(p.isEmpty)continue;try{final d=jsonDecode(p);if(d is Map<String,dynamic>)yield d;}catch(_){}}}catch(_){await Future<void>.delayed(const Duration(seconds:2));}}}
}
class ApiException implements Exception{const ApiException(this.message,this.statusCode);final String message;final int statusCode;@override String toString()=>message;}
