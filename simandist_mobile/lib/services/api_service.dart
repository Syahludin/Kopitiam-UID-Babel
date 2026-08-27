import 'dart:convert';
import 'package:http/http.dart' as http;
import 'device_session_service.dart';
class ApiService {
 static const String baseUrl=String.fromEnvironment('API_BASE_URL',defaultValue:'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec');
 static const _redirectCodes={301,302,303,307,308};
 static Future<http.Response> _get(Uri uri,{Duration timeout=const Duration(seconds:90)})async{final c=http.Client();var u=uri;try{for(var i=0;i<8;i++){final q=http.Request('GET',u)..followRedirects=false..headers['Accept']='application/json';final r=await http.Response.fromStream(await c.send(q).timeout(timeout));if(!_redirectCodes.contains(r.statusCode))return r;final l=r.headers['location'];if(l==null)break;u=u.resolve(l);}throw StateError('Redirect API gagal.');}finally{c.close();}}
 static Future<http.Response> _post(Map<String,dynamic> body)async{final c=http.Client();try{var r=await http.Response.fromStream(await c.send(http.Request('POST',Uri.parse(baseUrl))..followRedirects=false..headers['Content-Type']='application/json'..body=jsonEncode(body)).timeout(const Duration(seconds:120)));var i=0;while(_redirectCodes.contains(r.statusCode)&&i++<5){final l=r.headers['location'];if(l==null)break;r=await c.get(Uri.parse(baseUrl).resolve(l));}return r;}finally{c.close();}}
 static Map<String,dynamic> _decode(http.Response r){if(r.statusCode<200||r.statusCode>=300)throw StateError('API gagal (${r.statusCode}).');final v=jsonDecode(r.body);if(v is Map)return Map<String,dynamic>.from(v);throw StateError('Respons API tidak valid.');}
 static Future<Map<String,dynamic>> loginPerangkat(String u,String p)async{final d=await DeviceSessionService.deviceName();final r=_decode(await _get(Uri.parse(baseUrl).replace(queryParameters:{'action':'loginPerangkat','username':u,'password':p,'perangkat':d})));if(r['success']==true)await DeviceSessionService.save(deviceToken:'${r['deviceToken']??''}',profile:r);return r;}
 static Future<Map<String,dynamic>> cekPerangkat()async{final t=await DeviceSessionService.token();if(t.isEmpty)return {'success':false};return _decode(await _get(Uri.parse(baseUrl).replace(queryParameters:{'action':'cekPerangkat','deviceToken':t})));}
 static Future<Map<String,dynamic>> getMasterData(String t)=>_getMap({'action':'getMasterData','token':t});
 static Future<Map<String,dynamic>> getWoInsjar(String t)=>_getMap({'action':'getWoInsjar','token':t});
 static Future<Map<String,dynamic>> getTemuan(String t,String k)=>_getMap({'action':'getTemuanInspeksi','token':t,'kodeWo':k});
 static Future<Map<String,dynamic>> _getMap(Map<String,String> q)async=>_decode(await _get(Uri.parse(baseUrl).replace(queryParameters:q)));
 static Future<Map<String,dynamic>> syncWoInsjar(String t,List<Map<String,dynamic>> rows)async=>_decode(await _post({'action':'syncWoInsjar','token':t,'rows':rows}));
 static Future<Map<String,dynamic>> syncTemuan(String t,Map<String,dynamic> row)async=>_decode(await _post({'action':'syncTemuanInspeksi','token':t,'row':row}));
 static Future<Map<String,dynamic>> logoutPerangkat({String token=''})async{final d=await DeviceSessionService.token();try{return await _getMap({'action':'logoutPerangkat','deviceToken':d,'token':token});}finally{await DeviceSessionService.clear();}}
 static Future<Map<String,dynamic>> login(String u,String p)=>loginPerangkat(u,p);static Future<Map<String,dynamic>> cekSesi(String t)=>cekPerangkat();static Future<Map<String,dynamic>> logout(String t)=>logoutPerangkat(token:t);
}