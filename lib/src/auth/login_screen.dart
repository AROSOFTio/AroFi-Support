import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/support_models.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onAuthenticated});
  final ApiClient api;
  final ValueChanged<SupportUser> onAuthenticated;
  @override State<LoginScreen> createState()=>_LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>{
  final _email=TextEditingController(),_password=TextEditingController(),_otp=TextEditingController();
  bool _otpMode=false,_busy=false,_hidePassword=true; String? _error,_notice;
  @override void dispose(){_email.dispose();_password.dispose();_otp.dispose();super.dispose();}
  Future<void> _run(Future<void> Function() action) async {setState((){_busy=true;_error=null;});try{await action();}on ApiException catch(e){if(mounted)setState(()=>_error=e.message);}catch(_){if(mounted)setState(()=>_error='Could not connect to AroFi. Check your internet connection.');}finally{if(mounted)setState(()=>_busy=false);}}
  Future<void> _login()=>_run(()async{if(_email.text.trim().isEmpty||_password.text.isEmpty)throw const ApiException('Enter your email and password.',400);final result=await widget.api.loginStart(_email.text,_password.text);if(result['otpRequired']==true){setState((){_otpMode=true;_notice='We sent a 6-digit verification code to ${_email.text.trim()}.';});return;}await _finishLogin();});
  Future<void> _verify()=>_run(()async{if(_otp.text.trim().length!=6)throw const ApiException('Enter the 6-digit code.',400);await widget.api.verifyOtp(_email.text,_otp.text,rememberDevice:true);await _finishLogin();});
  Future<void> _finishLogin() async {final user=await widget.api.getMe();if(user==null)throw const ApiException('AroFi could not create your session.',401);if(!user.canReadSupport){await widget.api.logout();throw const ApiException('This account does not have access to the AroFi Support inbox.',403);}if(mounted)widget.onAuthenticated(user);}
  Future<void> _resend()=>_run(()async{await widget.api.resendOtp(_email.text);setState(()=>_notice='A fresh verification code has been sent.');});
  @override Widget build(BuildContext context){final c=Theme.of(context).colorScheme;return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Card(child:Padding(padding:const EdgeInsets.fromLTRB(28,28,28,30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.asset('assets/arofi_app_icon.png',width:52,height:52,fit:BoxFit.cover)),const SizedBox(width:14),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('AroFi Support',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),SizedBox(height:2),Text('Agent inbox',style:TextStyle(fontSize:13))]))]),
    const SizedBox(height:30),Text(_otpMode?'Verify your sign in':'Sign in to support',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800,letterSpacing:-.5)),const SizedBox(height:8),Text(_otpMode?'Use the same secure verification flow as the AroFi console.':'Use your existing AroFi support/staff account.'),
    if(_notice!=null)...[const SizedBox(height:18),_Banner(text:_notice!,color:c.primary)],if(_error!=null)...[const SizedBox(height:18),_Banner(text:_error!,color:c.error)],const SizedBox(height:22),
    if(!_otpMode)...[TextField(controller:_email,keyboardType:TextInputType.emailAddress,textInputAction:TextInputAction.next,autocorrect:false,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.alternate_email))),const SizedBox(height:14),TextField(controller:_password,obscureText:_hidePassword,onSubmitted:(_)=>_busy?null:_login(),decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>_hidePassword=!_hidePassword),icon:Icon(_hidePassword?Icons.visibility_outlined:Icons.visibility_off_outlined)))),const SizedBox(height:18),FilledButton.icon(onPressed:_busy?null:_login,icon:_busy?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login),label:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('Continue securely')))] else ...[
      TextField(controller:_otp,keyboardType:TextInputType.number,maxLength:6,textAlign:TextAlign.center,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700,letterSpacing:8),onSubmitted:(_)=>_busy?null:_verify(),decoration:const InputDecoration(labelText:'Verification code',counterText:'')),const SizedBox(height:18),FilledButton.icon(onPressed:_busy?null:_verify,icon:_busy?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.verified_user_outlined),label:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('Verify and sign in'))),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[TextButton(onPressed:_busy?null:()=>setState((){_otpMode=false;_otp.clear();}),child:const Text('Back')),TextButton(onPressed:_busy?null:_resend,child:const Text('Resend code'))])],
    const SizedBox(height:20),const Text('Only authorized AroFi staff with Support access can use this app.',textAlign:TextAlign.center,style:TextStyle(fontSize:11))]))))))));}
}

class _Banner extends StatelessWidget{const _Banner({required this.text,required this.color});final String text;final Color color;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withValues(alpha:.08),border:Border.all(color:color.withValues(alpha:.25)),borderRadius:BorderRadius.circular(10)),child:Text(text,style:TextStyle(color:color,fontSize:12.5,height:1.35)));}
