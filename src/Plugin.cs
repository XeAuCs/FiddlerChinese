using System;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Fiddler;

[assembly: RequiredVersion("4.6.0.0")]
[assembly: AssemblyTitle("Fiddler Chinese UI")]
[assembly: AssemblyDescription("Chinese UI translation; no traffic processing")]
[assembly: AssemblyVersion("2.0.0.0")]

namespace FiddlerChinese {
    public sealed class ChineseExtension : IFiddlerExtension {
        Localizer localizer;
        MenuItem menu;
        string folder;
        public void OnLoad() {
            try {
                folder=Path.Combine(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location),"FiddlerChinese");
                localizer=new Localizer(folder,Log);
                MenuItem toggle=new MenuItem("启用中文界面");toggle.Checked=true;
                toggle.Click+=delegate {toggle.Checked=!toggle.Checked;localizer.SetEnabled(toggle.Checked);};
                MenuItem reload=new MenuItem("重新加载翻译表",delegate {try {localizer.Reload();}catch(Exception e){Log(e.ToString());MessageBox.Show("翻译表加载失败，已保留上次翻译。", "Fiddler 中文界面");}});
                menu=new MenuItem("中文界面",new[]{toggle,reload});
                FiddlerApplication.UI.mnuTools.MenuItems.Add(menu);
                localizer.Attach(FiddlerApplication.UI);
                localizer.Start();
                Log("Started; Fiddler "+typeof(FiddlerApplication).Assembly.GetName().Version+"; dictionary="+localizer.TableCount);
            } catch(Exception ex) {Log(ex.ToString());if(localizer!=null)localizer.Dispose();}
        }
        void Log(string message) {
            try {
                if(!Directory.Exists(folder))return;
                string path=Path.Combine(folder,"FiddlerChinese.log");
                if(File.Exists(path)&&new FileInfo(path).Length>262144)File.WriteAllText(path,"");
                File.AppendAllText(path,DateTime.Now.ToString("s")+" "+message+Environment.NewLine);
            } catch { }
        }
        public void OnBeforeUnload() {
            if(localizer!=null){localizer.Dispose();localizer=null;}
            if(menu!=null){FiddlerApplication.UI.mnuTools.MenuItems.Remove(menu);menu.Dispose();menu=null;}
        }
    }
}
