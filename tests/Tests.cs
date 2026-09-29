using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;
using FiddlerChinese;

class Tests {
    static int passed;
    static string root,work,dict;
    static List<string> notes=new List<string>();
    static void Check(bool ok,string name) {if(!ok)throw new Exception("FAILED: "+name);passed++;Console.WriteLine("PASS "+name);}
    static IEnumerable<Control> All(Control c) {yield return c;foreach(Control child in c.Controls)foreach(Control d in All(child))yield return d;}
    static Control Find(Control c,string name) {foreach(Control item in All(c))if(item.Name==name)return item;throw new Exception("Control not found: "+name);}
    static void Pump() {for(int i=0;i<4;i++)Application.DoEvents();}
    static string FileHash(string path) {using(var sha=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path)));}
    static void Render(Control control,string name) {
        control.CreateControl();
        using(Bitmap bmp=new Bitmap(control.Width,control.Height)) {control.DrawToBitmap(bmp,new Rectangle(Point.Empty,control.Size));bmp.Save(Path.Combine(work,name+".png"));}
    }
    static Form PreviewHost(Form source) {
        Form host=new Form {Text=source.Text,ClientSize=source.ClientSize,Font=source.Font,ShowInTaskbar=false,StartPosition=FormStartPosition.Manual,Location=new Point(-20000,-20000)};
        var children=new List<Control>();foreach(Control c in source.Controls)children.Add(c);
        foreach(Control c in children)host.Controls.Add(c);
        host.Show();Pump();return host;
    }
    static void PureTests() {
        string dir=Path.Combine(work,"dictionary");Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir,"FiddlerTexts.txt"),"File==文件\nName==名称\nOne[LF]Two==一[LF]二\nTwo==二\nDuplicate==旧值\nDuplicate==新值\nEmpty==\nInvalid\n",Encoding.UTF8);
        File.WriteAllText(Path.Combine(dir,"FiddlerTexts.context.txt"),"System.Windows.Forms.Form|special|Text|Name==姓名\n",Encoding.UTF8);
        var t=TranslationTable.Load(Path.Combine(dir,"FiddlerTexts.txt"),Path.Combine(dir,"FiddlerTexts.context.txt"));
        Check(t.Lookup("","","Text","&File\tCtrl+F",true)=="文件(&F)\tCtrl+F","mnemonic and shortcut preserved");
        Check(t.Lookup("System.Windows.Forms.Form","special","Text","Name",false)=="姓名","context overrides generic translation");
        Check(t.Lookup("","","Text","One\r\nTwo",false)=="一\n二","CRLF and LF supported");
        Check(t.Lookup("","","Text","Duplicate",false)=="新值","last explicit override wins");
        Check(t.Lookup("","","Text","Empty",false)==null,"blank translation ignored");
        using(var form=new Form()) using(var l=new Localizer(dir,notes.Add)) {
            var label=new Label {Name="special",Text="Name"};
            var text=new TextBox {Text="Name"};
            var rich=new RichTextBox {Text="File"};
            var combo=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList};combo.Items.AddRange(new object[]{"Name","File"});combo.SelectedIndex=1;
            var editable=new ComboBox {Text="Name"};editable.Items.Add("Name");
            var list=new ListView();list.Items.Add("Name");list.Columns.Add("Name");
            var menu=new MenuItem("&File");var popup=new MenuItem("Name");menu.MenuItems.Add(popup);form.Menu=new MainMenu(new[]{menu});
            form.Controls.AddRange(new Control[]{label,text,rich,combo,editable,list});
            var handle=form.Handle;foreach(Control c in form.Controls){var h=c.Handle;}
            l.Attach(form);
            Check(label.Text=="姓名","real WinForms label translated");
            Check(text.Text=="Name"&&rich.Text=="File"&&editable.Text=="Name","editable data never translated");
            Check((string)combo.Items[1]=="File"&&combo.SelectedIndex==1&&combo.GetItemText(combo.Items[1])=="文件","dropdown display translated without modifying underlying value");
            Check(list.Items[0].Text=="Name"&&list.Columns[0].Text=="名称","list data protected while headers translated");
            Check(menu.Text=="文件(&F)"&&popup.Text=="名称","nested menus translated");
            var later=new Label {Text="File"};form.Controls.Add(later);Pump();
            Check(later.Text=="文件","late-added control translated");
            later.Text="Name";Pump();Check(later.Text=="名称","dynamic label changes translated");
            l.SetEnabled(false);Check(label.Text=="Name"&&later.Text=="Name"&&menu.Text=="&File","English restored on disable");
            Check(combo.GetItemText(combo.Items[1])=="File","dropdown English restored");
            l.SetEnabled(true);
            File.WriteAllText(Path.Combine(dir,"FiddlerTexts.txt"),"File==档案\nName==名字\n",Encoding.UTF8);l.Reload();
            Check(menu.Text=="档案(&F)"&&later.Text=="名字","dictionary reload updates existing controls");
            l.Dispose();Check(menu.Text=="&File"&&label.Text=="Name","dispose restores original labels");
        }
        // The active user's dictionary is never an output file.
        File.WriteAllText(Path.Combine(dir,"collect-missing.enabled"),"");
        string hash=FileHash(Path.Combine(dir,"FiddlerTexts.txt"));
        using(var l=new Localizer(dir,notes.Add))using(var f=new Form()) {
            f.Controls.Add(new Label {Name="unknown",Text="Untranslated caption"});
            f.Controls.Add(new TextBox {Name="requestBody",Text="Private user input"});
            l.Attach(f);l.SaveMissing();
            string missing=File.ReadAllText(Path.Combine(dir,"FiddlerTexts.missing.txt"));
            Check(missing.Contains("Untranslated caption")&&!missing.Contains("Private user input"),"missing-text collection excludes input contents");
        }
        Check(hash==FileHash(Path.Combine(dir,"FiddlerTexts.txt")),"reviewed dictionary never rewritten");
        using(var l=new Localizer(dict,notes.Add))using(var f=new Form()) {
            f.Text="Options";var before=f.Handle;f.Show();l.Discover();
            Check(f.Text=="选项","newly opened forms discovered");f.Close();
        }
    }
    static void RealTests() {
        Assembly asm=Assembly.LoadFrom(Path.Combine(root,"Fiddler.exe"));
        Form viewer=(Form)Activator.CreateInstance(asm.GetType("Fiddler.frmViewer"));
        asm.GetType("Fiddler.FiddlerApplication").GetField("_frmMain",BindingFlags.Static|BindingFlags.NonPublic|BindingFlags.Public).SetValue(null,viewer);
        Form options=(Form)Activator.CreateInstance(asm.GetType("Fiddler.frmOptions"),true);
        Assembly filters=Assembly.LoadFrom(Path.Combine(root,"Scripts/SimpleFilter.dll"));
        Control filter=(Control)Activator.CreateInstance(filters.GetType("SimpleFilter.FiltersEditor"));
        TabPage page=new TabPage("Filters");page.Name="pageFilters";page.Controls.Add(filter);filter.Dock=DockStyle.Fill;
        ((TabControl)Find(viewer,"tabsViews")).TabPages.Add(page);
        Dictionary<Control,string> inputs=new Dictionary<Control,string>();
        foreach(Control c in All(viewer))if(c is TextBoxBase || c is NumericUpDown)inputs[c]=c.Text;
        foreach(Control c in All(options))if(c is TextBoxBase || c is NumericUpDown)inputs[c]=c.Text;
        var combo=(ComboBox)Find(filter,"cbxHostAction");object[] comboItems=new object[combo.Items.Count];combo.Items.CopyTo(comboItems,0);int selected=combo.SelectedIndex;
        string before=FileHash(Path.Combine(dict,"FiddlerTexts.txt"));
        using(var l=new Localizer(dict,notes.Add)) {
            l.Attach(viewer);l.Attach(options);
            Check(viewer.Menu.MenuItems[0].Text=="文件(&F)","Fiddler 6 main menu translated");
            Check(Find(filter,"cbEnable").Text=="启用过滤器","actual Filters panel translated");
            Check(Find(options,"cbDecryptHTTPS").Text.StartsWith("解密 HTTPS 流量"),"actual HTTPS setting caption translated");
            Check(Find(options,"tabConnections").Text=="连接","actual Connections tab translated");
            foreach(var pair in inputs)Check(pair.Key.Text==pair.Value,"input unchanged: "+pair.Key.Name);
            Check(combo.SelectedIndex==selected,"Filters selection unchanged");
            for(int i=0;i<comboItems.Length;i++)Check(object.Equals(combo.Items[i],comboItems[i]),"Filters option value unchanged "+i);
            Check(combo.GetItemText(combo.Items[1])=="隐藏以下主机","Filters dropdown display translated");
            // Render the real controls without starting Fiddler's application loop or proxy.
            TabControl tabs=(TabControl)Find(options,"tabsOptions");
            Form preview=PreviewHost(options);
            for(int i=0;i<tabs.TabPages.Count;i++) {tabs.SelectedIndex=i;Pump();Render(preview,"options-"+tabs.TabPages[i].Name);}
            Form filterPreview=new Form {ClientSize=new Size(650,850),ShowInTaskbar=false,StartPosition=FormStartPosition.Manual,Location=new Point(-20000,-20000)};
            filterPreview.Controls.Add(filter);filter.Dock=DockStyle.Fill;filterPreview.Show();Pump();Render(filterPreview,"filters");
            List<string> labels=new List<string>();foreach(Control c in All(preview))if(Localizer.IsLabel(c))labels.Add(c.Name+"\t"+TranslationTable.Encode(c.Text));
            File.WriteAllLines(Path.Combine(work,"translated-options.tsv"),labels.ToArray(),Encoding.UTF8);
            Check(before==FileHash(Path.Combine(dict,"FiddlerTexts.txt")),"real UI translation leaves dictionary unchanged");
            l.SetEnabled(false);Check(options.Text=="Options"&&Find(filter,"cbEnable").Text=="Use Filters","real UI English restore");
            notes.Add("Real form replacements: "+l.Replacements);
            preview.Hide();filterPreview.Hide();
        }
        // Exercise the exported IFiddlerExtension against the actual host assembly.
        var plugin=new ChineseExtension();plugin.OnLoad();
        Check(viewer.Menu.MenuItems[0].Text=="文件(&F)","plugin OnLoad against actual Fiddler host");
        plugin.OnBeforeUnload();Check(viewer.Menu.MenuItems[0].Text=="&File","plugin unload restores host UI");
        // No Form.Close on the host viewer: its production closing handler persists settings.
        // The isolated process exits without invoking Fiddler's startup/proxy or closing workflow.
    }
    [STAThread] static int Main(string[] args) {
        try {
            root=Path.GetFullPath(args[0]);work=Path.GetFullPath(args[1]);dict=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"FiddlerChinese");Directory.CreateDirectory(work);
            AppDomain.CurrentDomain.AssemblyResolve+=delegate(object s,ResolveEventArgs e) {
                string name=new AssemblyName(e.Name).Name;string p=Path.Combine(root,name+".dll");
                if(!File.Exists(p))p=Path.Combine(root,name+".exe");if(!File.Exists(p))p=Path.Combine(root,"Scripts/"+name+".dll");
                return File.Exists(p)?Assembly.LoadFrom(p):null;
            };
            Application.EnableVisualStyles();PureTests();RealTests();
            notes.Add("PASS assertions: "+passed);File.WriteAllLines(Path.Combine(work,"results.txt"),notes.ToArray());
            Console.WriteLine("ALL PASSED: "+passed);return 0;
        }catch(Exception e){Console.WriteLine(e);return 1;}
    }
}
