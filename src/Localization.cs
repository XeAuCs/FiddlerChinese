using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using System.Windows.Forms;

namespace FiddlerChinese {
    public sealed class TranslationTable {
        readonly Dictionary<string,string> exact = new Dictionary<string,string>(StringComparer.Ordinal);
        readonly Dictionary<string,string> normalized = new Dictionary<string,string>(StringComparer.Ordinal);
        readonly HashSet<string> ambiguous = new HashSet<string>(StringComparer.Ordinal);
        public int Count { get { return exact.Count; } }
        public static string Decode(string s) { return s.Replace("[LF]", "\n").Replace("[TAB]", "\t").Replace("\r\n", "\n"); }
        public static string Encode(string s) { return s.Replace("\r\n", "\n").Replace("\n", "[LF]").Replace("\t", "[TAB]"); }
        public static string Normalize(string s) {
            s=s.Split('\t')[0];
            StringBuilder b=new StringBuilder();
            for(int i=0;i<s.Length;i++) { if(s[i]=='&') { if(i+1<s.Length && s[i+1]=='&') {b.Append('&');i++;} } else b.Append(s[i]); }
            return b.ToString().Trim().Replace("\r\n","\n");
        }
        public static TranslationTable Load(params string[] paths) {
            TranslationTable t = new TranslationTable();
            foreach(string p in paths) if(File.Exists(p)) {
                foreach(string line in File.ReadAllLines(p,Encoding.UTF8)) {
                    if(line.StartsWith("//",StringComparison.Ordinal)) continue;
                    int n=line.IndexOf("==",StringComparison.Ordinal);
                    if(n<=0) continue;
                    string key=Decode(line.Substring(0,n)), value=Decode(line.Substring(n+2));
                    if(value.Length==0 || key==value) continue;
                    t.exact[key]=value; // Later files explicitly override built-in translations.
                }
            }
            foreach(KeyValuePair<string,string> pair in t.exact) {
                if(pair.Key.Contains("|")) continue;
                string key=Normalize(pair.Key), value=Normalize(pair.Value);
                string old;
                if(t.normalized.TryGetValue(key,out old) && old!=value) t.ambiguous.Add(key);
                else t.normalized[key]=value;
            }
            return t;
        }
        public string Lookup(string scope,string name,string property,string text,bool mnemonic) {
            if(string.IsNullOrEmpty(text)) return null;
            string value;
            string input=text.Replace("\r\n","\n");
            if(!exact.TryGetValue(scope+"|"+name+"|"+property+"|"+input,out value) &&
               !exact.TryGetValue(input,out value)) {
                string key=Normalize(input);
                if(ambiguous.Contains(key) || !normalized.TryGetValue(key,out value)) return null;
            }
            string suffix="";
            int tab=input.IndexOf('\t');
            if(tab>=0 && value.IndexOf('\t')<0) suffix=input.Substring(tab);
            if(mnemonic && value.IndexOf('&')<0) {
                for(int i=0;i<input.Length-1;i++) if(input[i]=='&') {
                    if(input[i+1]=='&') {i++;continue;}
                    if(char.IsLetterOrDigit(input[i+1])) {
                        int split=value.IndexOf('\t');
                        string mark="(&"+char.ToUpperInvariant(input[i+1])+")";
                        value=split<0?value+mark:value.Insert(split,mark);
                    }
                    break;
                }
            }
            return value+suffix;
        }
    }

    public sealed class Localizer : IDisposable {
        sealed class Slot { public string Original, Applied; public Func<string> Read; public Action<string> Write; public string Scope,Name,Property; public bool Mnemonic; }
        sealed class State { public bool Bound,StripBound; public Dictionary<string,Slot> Slots=new Dictionary<string,Slot>(); }
        readonly ConditionalWeakTable<object,State> states=new ConditionalWeakTable<object,State>();
        readonly List<WeakReference> known=new List<WeakReference>();
        readonly HashSet<Control> pending=new HashSet<Control>();
        readonly List<Action> unhook=new List<Action>();
        readonly HashSet<Form> forms=new HashSet<Form>();
        readonly HashSet<string> missing=new HashSet<string>(StringComparer.Ordinal);
        readonly string folder;
        readonly Action<string> log;
        readonly ToolTip overflow=new ToolTip();
        readonly Timer discovery=new Timer();
        TranslationTable table;
        bool changing,disposed,enabled=true, collect;
        DateTime lastWrite=DateTime.MinValue;
        public int Replacements { get; private set; }
        public int TableCount { get { return table.Count; } }
        public bool Enabled { get {return enabled;} }
        public Localizer(string folder,Action<string> log) {
            this.folder=Path.GetFullPath(folder); this.log=log ?? delegate(string s){};
            Reload();
            discovery.Interval=500;
            discovery.Tick+=delegate { Discover(); };
        }
        public void Start() { Discover(); discovery.Start(); }
        public void Reload() {
            // Read both files completely before replacing the active dictionary.
            TranslationTable next=TranslationTable.Load(Path.Combine(folder,"FiddlerTexts.txt"),Path.Combine(folder,"FiddlerTexts.context.txt"));
            table=next; collect=File.Exists(Path.Combine(folder,"collect-missing.enabled"));
            Refresh(); log("Loaded "+table.Count+" translations.");
        }
        public void SetEnabled(bool value) { enabled=value; Refresh(); }
        void Refresh() {
            if(disposed || table==null) return;
            foreach(WeakReference weak in known.ToArray()) {
                object owner=weak.Target; State state;
                if(owner==null || !states.TryGetValue(owner,out state)) continue;
                foreach(Slot slot in new List<Slot>(state.Slots.Values)) ApplySlot(slot);
                Control c=owner as Control; if(c!=null && !c.IsDisposed) c.Invalidate();
            }
        }
        State Get(object owner) {
            State state;
            if(!states.TryGetValue(owner,out state)) { state=new State(); states.Add(owner,state); known.Add(new WeakReference(owner)); }
            return state;
        }
        void Change(object owner,string key,string scope,string name,Func<string> read,Action<string> write,bool mnemonic) {
            State state=Get(owner); Slot slot;
            if(!state.Slots.TryGetValue(key,out slot)) {
                slot=new Slot { Original=read(),Read=read,Write=write,Scope=scope,Name=name,Property=key,Mnemonic=mnemonic };
                state.Slots[key]=slot;
            }
            ApplySlot(slot);
        }
        void ApplySlot(Slot slot) {
            try {
                string current=slot.Read();
                if(current!=slot.Applied && current!=slot.Original) slot.Original=current;
                string translated=enabled?table.Lookup(slot.Scope,slot.Name,slot.Property,slot.Original,slot.Mnemonic):null;
                if(translated==null && enabled && collect && IsCandidate(slot.Original))
                    missing.Add(slot.Scope+"|"+slot.Name+"|"+slot.Property+"|"+TranslationTable.Encode(slot.Original)+"=="+TranslationTable.Encode(slot.Original));
                string result=translated ?? slot.Original;
                if(current!=result) { bool before=changing; changing=true; try {slot.Write(result);Replacements++;} finally {changing=before;} }
                slot.Applied=result;
            } catch(ObjectDisposedException) {} catch(Exception ex) {log("Translate: "+ex.GetType().Name);}
        }
        static bool IsCandidate(string s) {
            if(string.IsNullOrWhiteSpace(s)||s.Length>1400||s.Contains("://")||s.Contains("\\")||s.Contains("@")) return false;
            foreach(char ch in s) {if(ch>='\u4e00' && ch<='\u9fff') return false;}
            foreach(char ch in s) if(ch>='A'&&ch<='Z'||ch>='a'&&ch<='z') return true;
            return false;
        }
        public void Discover() {
            if(disposed) return;
            try {
                List<Form> snapshot=new List<Form>(); foreach(Form open in Application.OpenForms) snapshot.Add(open);
                foreach(Form f in snapshot) if(f!=null && !f.IsDisposed && !forms.Contains(f) && !f.InvokeRequired) Attach(f);
                known.RemoveAll(delegate(WeakReference w){return !w.IsAlive;});
                if(collect && missing.Count>0 && (DateTime.UtcNow-lastWrite).TotalSeconds>=10) {SaveMissing();lastWrite=DateTime.UtcNow;}
            } catch(Exception ex) {log("Discover: "+ex.GetType().Name);}
        }
        public void Attach(Form f) {
            if(disposed||f.IsDisposed||forms.Contains(f)) return;
            forms.Add(f);
            FormClosedEventHandler closed=delegate {forms.Remove(f);}; f.FormClosed+=closed;
            // Removal on close prevents retaining all past dialogs through cleanup delegates.
            EventHandler release=null;
            Action cleanup=delegate {f.FormClosed-=closed;f.Disposed-=release;};
            release=delegate {forms.Remove(f);unhook.Remove(cleanup);}; f.Disposed+=release;
            unhook.Add(cleanup);
            TranslateTree(f);
            if(f.Menu!=null) TranslateMenu(f.Menu,f.GetType().FullName);
        }
        void Queue(Control c) {
            if(disposed||changing||c.IsDisposed) return;
            Control dispatcher=c;
            while(dispatcher!=null&&!dispatcher.IsHandleCreated) dispatcher=dispatcher.Parent;
            if(dispatcher==null||!pending.Add(c)) return;
            try {dispatcher.BeginInvoke((MethodInvoker)delegate {pending.Remove(c);if(!disposed&&!c.IsDisposed) TranslateTree(c);});}
            catch(InvalidOperationException) {pending.Remove(c);}
        }
        static string Scope(Control c) {
            // Use the declaring UserControl for plugin panels, otherwise the owning form.
            for(Control p=c;p!=null;p=p.Parent) if(p is UserControl && p.GetType()!=typeof(UserControl)) return p.GetType().FullName;
            Form f=c.FindForm(); return f==null?c.GetType().FullName:f.GetType().FullName;
        }
        public static bool IsLabel(Control c) { return c is Label || c is ButtonBase || c is GroupBox || c is TabPage || c is Form; }
        public void TranslateTree(Control c) {
            if(disposed||c.IsDisposed) return;
            try {
                string scope=Scope(c); State state=Get(c);
                if(!state.Bound) {
                    state.Bound=true;
                    ControlEventHandler added=delegate(object s,ControlEventArgs e){Queue(c);};
                    EventHandler changed=delegate {Queue(c);};
                    c.ControlAdded+=added; c.HandleCreated+=changed; c.VisibleChanged+=changed;
                    if(IsLabel(c)) c.TextChanged+=changed;
                    EventHandler released=null;
                    Action cleanup=delegate {c.ControlAdded-=added;c.HandleCreated-=changed;c.VisibleChanged-=changed;c.TextChanged-=changed;c.Disposed-=released;};
                    released=delegate {pending.Remove(c);unhook.Remove(cleanup);}; c.Disposed+=released;unhook.Add(cleanup);
                    ToolStrip watchedStrip=c as ToolStrip;
                    if(watchedStrip!=null) {
                        ToolStripItemEventHandler itemAdded=delegate {Queue(watchedStrip);};watchedStrip.ItemAdded+=itemAdded;
                        Action remove=delegate {watchedStrip.ItemAdded-=itemAdded;};unhook.Add(remove);
                        watchedStrip.Disposed+=delegate {unhook.Remove(remove);};
                    }
                    ComboBox combo=c as ComboBox;
                    if(combo!=null && combo.DropDownStyle==ComboBoxStyle.DropDownList && combo.DataSource==null) {
                        // Format changes the presentation, never Items, SelectedIndex or stored values.
                        bool previous=combo.FormattingEnabled;
                        ListControlConvertEventHandler format=delegate(object s,ListControlConvertEventArgs e) {
                            if(enabled && e.ListItem is string) e.Value=table.Lookup(Scope(combo),combo.Name,"Item",(string)e.ListItem,false) ?? e.Value;
                        };
                        combo.Format+=format;combo.FormattingEnabled=true;
                        Action undoFormat=delegate {combo.Format-=format;combo.FormattingEnabled=previous;};
                        EventHandler removeFormat=delegate {unhook.Remove(undoFormat);};combo.Disposed+=removeFormat;unhook.Add(undoFormat);
                    }
                    BindComponents(c);
                }
                if(IsLabel(c)) {
                    Change(c,"Text",scope,c.Name,delegate{return c.Text;},delegate(string s){c.Text=s;}, !(c is Form || c is TabPage));
                    Fit(c);
                }
                // QuickExec's prompt is separate from user-editable Text.
                if(c.GetType().FullName=="Fiddler.QuickExec") {
                    PropertyInfo cue=c.GetType().GetProperty("CueText");
                    if(cue!=null&&cue.CanWrite) Change(c,"CueText",scope,c.Name,delegate{return (string)cue.GetValue(c,null);},delegate(string s){cue.SetValue(c,s,null);},false);
                }
                ToolStrip strip=c as ToolStrip; if(strip!=null) BindStrip(strip,scope);
                ListView list=c as ListView; if(list!=null) foreach(ColumnHeader column in list.Columns) {
                    ColumnHeader col=column;Change(col,"Text",scope,list.Name+"/"+col.Index,delegate{return col.Text;},delegate(string s){col.Text=s;},false);
                }
                if(c.ContextMenu!=null) TranslateMenu(c.ContextMenu,scope);
                if(c.ContextMenuStrip!=null) BindStrip(c.ContextMenuStrip,scope);
                foreach(Control child in c.Controls) TranslateTree(child);
            } catch(Exception ex) {log("Control "+c.GetType().Name+": "+ex.GetType().Name);}
        }
        void Fit(Control c) {
            if(!enabled||!(c is Label || c is ButtonBase)||c.AutoSize||c.Parent==null||c.Dock!=DockStyle.None) return;
            // Use a full-text tooltip when fixed-size controls cannot contain Chinese.
            Size size=TextRenderer.MeasureText(c.Text,c.Font,new Size(Math.Max(1,c.Width-8),int.MaxValue),TextFormatFlags.WordBreak);
            if(size.Height>c.Height || size.Width>c.Width) overflow.SetToolTip(c,c.Text.Replace("&",""));
        }
        void BindComponents(Control owner) {
            string scope=Scope(owner);
            for(Type type=owner.GetType();type!=null && type!=typeof(Control);type=type.BaseType) {
                foreach(FieldInfo field in type.GetFields(BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.DeclaredOnly)) {
                    try {
                        if(typeof(ToolTip).IsAssignableFrom(field.FieldType)) {
                            ToolTip tip=field.GetValue(owner) as ToolTip;if(tip!=null) TranslateTips(tip,owner,scope);
                        } else if(typeof(Menu).IsAssignableFrom(field.FieldType)) {
                            Menu m=field.GetValue(owner) as Menu;if(m!=null) TranslateMenu(m,scope);
                        } else if(typeof(ContextMenuStrip).IsAssignableFrom(field.FieldType)) {
                            ContextMenuStrip m=field.GetValue(owner) as ContextMenuStrip;if(m!=null) BindStrip(m,scope);
                        }
                    } catch(Exception ex) {log("Component: "+ex.GetType().Name);}
                }
            }
        }
        void TranslateTips(ToolTip tip,Control c,string scope) {
            string text=tip.GetToolTip(c);
            if(!string.IsNullOrEmpty(text)) Change(c,"ToolTip",scope,c.Name,delegate{return tip.GetToolTip(c);},delegate(string s){tip.SetToolTip(c,s);},false);
            foreach(Control child in c.Controls) TranslateTips(tip,child,scope);
        }
        public void TranslateMenu(Menu menu,string scope) {
            foreach(MenuItem child in menu.MenuItems) {
                MenuItem item=child; State state=Get(item);
                Change(item,"Text",scope,item.Name,delegate{return item.Text;},delegate(string s){item.Text=s;},true);
                if(!state.Bound) {
                    state.Bound=true;
                    EventHandler popup=delegate {if(!disposed) TranslateMenu(item,scope);};item.Popup+=popup;
                    Action cleanup=delegate {item.Popup-=popup;};unhook.Add(cleanup);
                    item.Disposed+=delegate {unhook.Remove(cleanup);};
                }
                TranslateMenu(item,scope);
            }
        }
        void BindStrip(ToolStrip strip,string scope) {
            State state=Get(strip);
            if(!state.StripBound) {
                state.StripBound=true;
                ToolStripDropDown drop=strip as ToolStripDropDown;
                CancelEventHandler opening=delegate {if(!disposed)TranslateItems(strip.Items,scope);};
                if(drop!=null) {
                    drop.Opening+=opening;
                    Action undo=delegate {drop.Opening-=opening;};unhook.Add(undo);
                    drop.Disposed+=delegate {unhook.Remove(undo);};
                }
            }
            TranslateItems(strip.Items,scope);
        }
        void TranslateItems(ToolStripItemCollection items,string scope) {
            foreach(ToolStripItem child in items) {
                ToolStripItem item=child;
                if(item is ToolStripControlHost) continue;
                Change(item,"Text",scope,item.Name,delegate{return item.Text;},delegate(string s){item.Text=s;},true);
                Change(item,"ToolTipText",scope,item.Name,delegate{return item.ToolTipText;},delegate(string s){item.ToolTipText=s;},false);
                State state=Get(item);
                ToolStripDropDownItem drop=item as ToolStripDropDownItem;
                if(!state.Bound) {
                    state.Bound=true;
                    EventHandler change=delegate {if(!disposed&&!changing&&item.Owner!=null) Queue(item.Owner);};item.TextChanged+=change;
                    EventHandler opening=delegate {if(!disposed&&drop!=null) TranslateItems(drop.DropDownItems,scope);};if(drop!=null)drop.DropDownOpening+=opening;
                    Action cleanup=delegate {item.TextChanged-=change;if(drop!=null)drop.DropDownOpening-=opening;};unhook.Add(cleanup);
                    item.Disposed+=delegate {unhook.Remove(cleanup);};
                }
                if(drop!=null) TranslateItems(drop.DropDownItems,scope);
            }
        }
        public void SaveMissing() {
            if(!collect||missing.Count==0) return;
            try {
                string path=Path.Combine(folder,"FiddlerTexts.missing.txt");
                HashSet<string> all=new HashSet<string>(missing);
                if(File.Exists(path)) foreach(string line in File.ReadAllLines(path)) all.Add(line);
                List<string> lines=new List<string>(all);lines.Sort(StringComparer.Ordinal);
                string temp=path+".tmp";File.WriteAllLines(temp,lines.ToArray(),new UTF8Encoding(true));
                if(File.Exists(path)) File.Replace(temp,path,null); else File.Move(temp,path);
                missing.Clear();
            } catch(Exception ex) {log("Missing file: "+ex.GetType().Name);}
        }
        public void Dispose() {
            if(disposed)return;
            discovery.Stop();discovery.Dispose();
            SetEnabled(false);SaveMissing();disposed=true;
            foreach(Action action in unhook.ToArray()) try {action();} catch(ObjectDisposedException) {}
            unhook.Clear();forms.Clear();pending.Clear();known.Clear();overflow.Dispose();
        }
    }
}
