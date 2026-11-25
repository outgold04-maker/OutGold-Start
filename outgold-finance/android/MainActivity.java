package com.outgold.finance;
import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.webkit.*;
import android.view.ViewGroup;
import android.widget.Toast;
import java.nio.charset.StandardCharsets;
import java.io.OutputStream;
public class MainActivity extends Activity {
 WebView web; ValueCallback<Uri[]> picker; byte[] pending;
 @Override public void onCreate(Bundle b){super.onCreate(b);web=new WebView(this);setContentView(web,new ViewGroup.LayoutParams(-1,-1));web.setBackgroundColor(0xff10100e);WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(true);s.setAllowContentAccess(true);s.setAllowFileAccessFromFileURLs(false);s.setAllowUniversalAccessFromFileURLs(false);web.addJavascriptInterface(new Bridge(),"OutGoldAndroid");web.setWebViewClient(new WebViewClient(){@Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !"file".equals(r.getUrl().getScheme());}});web.setWebChromeClient(new WebChromeClient(){@Override public boolean onShowFileChooser(WebView w,ValueCallback<Uri[]> c,FileChooserParams p){if(picker!=null)picker.onReceiveValue(null);picker=c;try{startActivityForResult(p.createIntent(),31);}catch(Exception e){picker.onReceiveValue(null);picker=null;}return true;}});web.loadUrl("file:///android_asset/index.html");}
 class Bridge {@JavascriptInterface public void save(String name,String data,String mime){runOnUiThread(()->{pending=data.getBytes(StandardCharsets.UTF_8);Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType(mime.split(";")[0]);i.putExtra(Intent.EXTRA_TITLE,name);try{startActivityForResult(i,32);}catch(Exception e){pending=null;Toast.makeText(MainActivity.this,"Não foi possível abrir o seletor.",Toast.LENGTH_LONG).show();}});}@JavascriptInterface public void print(){runOnUiThread(()->{android.print.PrintManager pm=(android.print.PrintManager)getSystemService(PRINT_SERVICE);pm.print("OutGold Finance",web.createPrintDocumentAdapter("OutGold Finance"),null);});}}
 @Override protected void onActivityResult(int req,int res,Intent data){super.onActivityResult(req,res,data);if(req==31&&picker!=null){picker.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(res,data));picker=null;}if(req==32){try{if(res==RESULT_OK&&data!=null&&pending!=null){try(OutputStream o=getContentResolver().openOutputStream(data.getData())){o.write(pending);}Toast.makeText(this,"Arquivo salvo.",Toast.LENGTH_SHORT).show();}}catch(Exception ex){Toast.makeText(this,"Falha ao salvar arquivo.",Toast.LENGTH_LONG).show();}finally{pending=null;}}}
 @Override public void onBackPressed(){web.evaluateJavascript("document.getElementById('overlay').classList.contains('open')",r->{if("true".equals(r))web.evaluateJavascript("close()",null);else super.onBackPressed();});}
}