state("eldenring")
{
}

startup
{
    vars.ShouldReset = false;
    vars.ER = null;

    Console.Clear();
    Console.WriteLine(DateTime.Now.ToString());

    #region log

    vars.Msgb = (Action<String>)((text) =>
    {
        MessageBox.Show(text,"SoulMemScript",MessageBoxButtons.OK,MessageBoxIcon.Information);
    });

    vars.Log = (Action<String>) ((text) =>
    {
        print(String.Format("[ER boss timer] {0}",text));
        Console.WriteLine(String.Format("[ER boss timer] {0}",text));
    });
    vars.Logt = (Action<String,String>)((title,text)=>
    {
        print(String.Format("[ER boss timer : {0}] {1}",title,text));
        Console.WriteLine(String.Format("[ER boss timer : {0}] {1}",title,text));

    });
    #endregion
    
    #region Create/Find Textboxes
    var controls = new Dictionary<String,LiveSplit.UI.Components.ILayoutComponent>();
    vars.GetControl = (Func<String,object>)((controlName)=>
    {
        LiveSplit.UI.Components.ILayoutComponent control = null;
        if (!controls.TryGetValue(controlName,out control))
        {
            foreach (var c in timer.Layout.LayoutComponents) // try to find it in layout
            {
                try
                {
                    dynamic comp = c.Component;
                    if (comp.Settings.Text1 == controlName)
                    {
                            controls[controlName] = control =  c;
                            vars.Logt("control found", controlName);
                            break;
                    }
                }
                catch 
                {
                    
                }
            }
            if (control == null)
            {
                controls[controlName]= control = LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent("LiveSplit.Text.dll",timer);
                vars.Logt("control created", controlName);
            }
            if (!timer.Layout.LayoutComponents.Contains(control))
            {
                vars.Logt("control added", controlName);
                timer.Layout.LayoutComponents.Add(control);
            }
        }
        return (object)control;

    });

    vars.CreateSeparator = (Action<bool>)((ignoreExistant)=>
    {
        bool found = false;
            foreach (var c in timer.Layout.LayoutComponents)
            {
                if(c.Component is LiveSplit.UI.Components.SeparatorComponent)
                {
                    vars.Logt("Sperator", "Existing");
                    found = true;
                    break;
                }
        }
        if (ignoreExistant || !found)
        {
            var compo = new LiveSplit.UI.Components.LayoutComponent("",new LiveSplit.UI.Components.SeparatorComponent());
            timer.Layout.LayoutComponents.Add(compo);
            vars.Logt("Separator","Created");
        }
    });
    #endregion

    #region Update textboxes

    vars.SetText = (Action<String,String>)((Value1,Value2)=>
    {
        dynamic component = vars.GetControl(Value1).Component;
        component.Settings.Text1 = Value1;
        if (Value2!=null)
            component.Settings.Text2 = Value2;    
    });


    /* category of run (all bosses, all remembrances..etc)
    0 Custom
    1 All bosses
    2 All base game
    3 All remembrances
    4 All DLC bosses
    5 Main DLC bosses (remembrances + bayle)
    */
    vars.DisplayCategory = (Action<object>)((category) =>
    {
        string text = null;

        var categories = new string[]{
            "Custom",
            "All bosses",
            "Base game bosses",
            "All remembrances",
            "DLC all bosses",
            "Main DLC Bosses"
        };
        if (category!=null)
        {
            int iCategory = (int)category;
            if (iCategory >= categories.Length || iCategory < 0)
            {
                iCategory = 0;
            }
            text = categories[iCategory];
        }
        // Console.WriteLine(text == null? "" : text);
        vars.SetText("Category",text);

    });


    vars.DisplayKilledBosses = (Action<object>)((text)=>
    {
        vars.SetText("Killed bosses",text);
    });

    vars.DisplayPrevBossTime = (Action<object>)((time)=>
    {
        vars.SetText("Previous fight time",time == null ? null : new DateTime(((TimeSpan)time).Ticks).ToString("HH:mm:ss.ff"));
    });


    vars.DisplayDeathCounter = (Action<int?>)((counter) =>
    {
        vars.SetText("Death counter",counter == null ? null : counter.ToString());

    });

    vars.DisplayPreviousKillTime = (Action<object>)((time)=>
    {
        vars.SetText("Previous boss time",time ==null ? null : new DateTime(((TimeSpan)time).Ticks).ToString("HH:mm:ss.ff"));
    });

    vars.DisplayPrevBossName = (Action<String>)((name)=>
    {
        vars.SetText("=",name);
    });

    vars.DisplayNumOfGreatRunes = (Action<int?>)((number)=>
    {
        vars.SetText("Great runes",number == null ? null : number.ToString());
    });

    vars.DisplayDefeatedBosses = (Action<String>)((text)=>{
        vars.SetText("Defeated bosses",text);
    });
    #endregion

    #region Correct timing method
         
    if (timer.CurrentTimingMethod != TimingMethod.GameTime)
    {
        if (DialogResult.Yes ==  
            MessageBox.Show("This split uses GameTime as timing method, switch now?",
            "LiveSplit : Eldenring boss timer",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question))
        {
            timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
    }
    #endregion

    #region AOB pattern scan functions
    // Pattern copied from GrandArchives cheat engine table
    vars.sigScanTarget = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 48 85 C0 74 05 48 8B 40 58 C3 C3");
    vars.ReadPointer = (Func<Process,IntPtr,IntPtr>)((proc,ptr) =>
    {
        return proc.ReadPointer(ptr);
    });

    vars.ReadInt = (Func<Process,IntPtr,Int32>)((proc,ptr) =>
    {
        return proc.ReadValue<Int32>(ptr);
    });

    // credits to https://github.com/drtchops/asl/blob/master/dxmd.asl
    vars.ReadOffset = (Func<Process, IntPtr, int, int, IntPtr>)((proc, ptr, offsetSize, remainingBytes) =>
        {
            byte[] offsetBytes;
            if (ptr == IntPtr.Zero || !proc.ReadBytes(ptr, offsetSize, out offsetBytes))
                return IntPtr.Zero;

            int offset;
            switch (offsetSize)
            {
                case 1:
                    offset = offsetBytes[0];
                    break;
                case 2:
                    offset = BitConverter.ToInt16(offsetBytes, 0);
                    break;
                case 4:
                    offset = BitConverter.ToInt32(offsetBytes, 0);
                    break;
                default:
                    throw new Exception("Unsupported offset size");
            }
            return ptr + offsetSize + remainingBytes + offset;
        });
    #endregion

    #region Load soulmemory.dll

    vars.ResetBosses = (Action)(()=>
    {
        vars.RemainingBoss = new List<uint>();
        foreach(var kvp in vars.BossesNames)
        {
            vars.RemainingBoss.Add(kvp.Key);
        }
    });

    vars.LoadSoulMem = (Func<bool>)(()=> 
    {
        try
        {
            var dir = Path.GetDirectoryName(timer.GetType().Assembly.Location);
            var location = Path.Combine(dir,"components","soulmemory.dll");
            if (!File.Exists(location))
            {
                vars.err = "soulmemory.dll not found";
                return false;
            }
            
            vars.Logt("soulmemory.dll", "found");

            vars.err = "Can't load soulmemory.dll";
            var asm = System.Reflection.Assembly.UnsafeLoadFrom(location);
            vars.Logt("soulmemory.dll","loaded");
            
            vars.err = "Can't create instance of SoulMemory.EldenRing.EldenRing";
            dynamic instance = asm.CreateInstance("SoulMemory.EldenRing.EldenRing");
            vars.ER = instance;
            vars.Logt("SoulMemory.EldenRing.EldenRing", "instance created");

            vars.err = "Can't get SoulMemory.EldenRing.Boss";
            var bosses = asm.GetType("SoulMemory.EldenRing.Boss"); // enum of bosses


            vars.err = "Can't read EldenRing memory";
            vars.BossesNames = new Dictionary<uint,string>();
            // vars.bossStates = new Dictionary<uint,bool>();
            vars.ER.TryRefresh();


            vars.err = "Can't enumerate bosses";
            var BaseGameBosses = new List<uint>();
            var DLCBosses = new List<uint>();
            vars.MainDLCBosses = new uint[]{
                2054390800, // Bayle
                21010800, // Messmer
                25000800, // Metyr
                2048440800, // Rellana
                2049480800, // Gaius
                2050480800, // Scadutree avatar
                28000800, // Midra,
                13000830, // Romina
                20000800, // Divine Beast
                22000800, // Putrescent Knight
                20010800 // Consort Radahn
            };
            vars.RemembranceBosses = new uint[]{
                10000800, // Godrick
                1252380800, // Starscourge Radahn
                14000800, // Rennala
                11000800, // Morgot
                11050800, // Hoara loux
                1052520800, // Fire Giant
                15000800, // Malenia
                16000800, // Rykard
                19000800, // Elden beast
                12050800, // Mohg lord of blood
                12050800, // Regal ancestra spirit
                13000800, // Maliketh
                13000830, // Placidusax
                12040800, // Astel
                12030850, // Fortissax
                // 2054390800, // Bayle
                21010800, // Messmer
                25000800, // Metyr
                2048440800, // Rellana
                2049480800, // Gaius
                2050480800, // Scadutree avatar
                28000800, // Midra,
                13000830, // Romina
                20000800, // Divine Beast
                22000800, // Putrescent Knight
                20010800 // Consort Radahn
            };

            List<string> DLClocations = new List<string>() { 
                "Enir-Ilim",
                "Abyssal Woods",
                "Scaduview",
                "Jagged Peak",
                "Charo's Hidden Grave",
                "Cerulean Coast",
                "Church of the Bud",
                "Ancient Ruins of Rauh",
                "Shadow Keep",
                "Scadu Altus",
                "Castle Ensis",
                "Belurat, Tower Settlement",
                "Gravesite Plain"};
            // var currentList = BaseGameBosses;

            foreach (var boss in Enum.GetValues(bosses))
            {
                if (boss !=null)
                {
                    dynamic attr = boss.GetType().GetMember(boss.ToString()).FirstOrDefault().GetCustomAttributes().FirstOrDefault();
                    vars.BossesNames[(uint)boss] = attr.Name;

                    if (DLClocations.Contains(attr.Description))
                    {
                        DLCBosses.Add((uint)boss);
                    }
                    else
                    {
                        BaseGameBosses.Add((uint)boss);
                    }
                //     // vars.bossStates[(uint)boss]= vars.ER.ReadEventFlag((uint)boss);
                }
            }

            vars.BaseGameBosses = BaseGameBosses.ToArray();
            vars.DLCBosses = DLCBosses.ToArray();


            vars.ResetBosses();
            vars.Log("Bosses enumerated"); 
            
        }
        catch
        {
            vars.ER = null;
            return false;
        }
        return true;
    });
    // vars.ItemFromLookupTable = (Func<UInt32,UInt32,object>)((Category,ItemID) =>
    // {
    //     if (vars.ER == null)
    //         return null;
    //     var ItemClass = vars.ER.GetType().Assembly.GetType("SoulMemory.EldenRing.Item");
    //     var FromLookupTable = ItemClass.GetMethod("FromLookupTable");
    //     var CategoryClass = vars.ER.GetType().Assembly.GetType("SoulMemory.EldenRing.Category");

    //     var category = Enum.ToObject(CategoryClass, Category);
    //     var itm = FromLookupTable.Invoke(null, new object[]{category,ItemID});
    //     return itm;
    // });
    #endregion

    #region Config

    settings.Add("Custom category (default)"); // 0
    settings.Add("All bosses"); // 1
    settings.Add("All Base game bosses"); // 2
    settings.Add("All remembrances"); // 3
    settings.Add("All DLC Bosses"); // 4
    settings.Add("Main DLC bosses"); // 5

    /*
    0 Custom (display number of defeated bosses)
    1 All bosses (number of defeated bosses / total bosses)
    2 All base game (defeated base game bosses / base game bosses)
    3 All remembrances (defeated remembrances / all remembrances)
    4 All DLC bosses (defeated dlc bosses / all dlc bosses)
    5 Main DLC bosses AKA DLC remembrances + bayle (defeated main dlc bosses / all main dlc bosses)
    */
    vars.Category = 0;


    #endregion

    #region Reset/init controls

    vars.Reset = (Action<bool>)((keepValues)=>{
        if (vars.ER!=null)
        {
            vars.ResetBosses();
        }
        vars.LastBattleWon = false;
        vars.IsPlayerLoaded = false;
        vars.DisplayCategory(vars.Category);
        vars.DisplayDefeatedBosses("0");
        vars.DisplayDeathCounter(0);
        vars.DisplayNumOfGreatRunes(0);
        // conditional operator doesn't work for ssome reason, I had to do an if else statment
        if (keepValues)
        {
            vars.DisplayPrevBossTime(null); // updated after each boss fight
            vars.CreateSeparator(false);
            vars.DisplayPreviousKillTime(null); // updated at the end of a winnig boss battle
            vars.DisplayPrevBossName(null);
        }
        else
        {
            vars.DisplayPrevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero); // updated after each boss fight
            vars.CreateSeparator(false);
            vars.DisplayPreviousKillTime(TimeSpan.Zero); // updated at the end of a winnig boss battle
            vars.DisplayPrevBossName(" ");
        }
    });
    vars.Reset(true);
    vars.Startup = true; // don't set boss name at first startup
    #endregion
}

init
{
    vars.Logt("Init","");
    var module = modules.FirstOrDefault(m => m.ModuleName.ToLower() == "eldenring.exe");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
    var codeLocation = scanner.Scan(vars.sigScanTarget);
    vars.Logt("pattern found", codeLocation.ToString("X"));
    	
    var pointer = vars.ReadOffset(game,codeLocation,4,0);
    vars.Logt("pointer", pointer.ToString("X"));

    var GameDataMan = vars.ReadPointer(game,pointer);
    vars.GameDataMan = GameDataMan;
    vars.Logt("GameDataMan", GameDataMan.ToString("X"));
    
    vars.IsBossFight = new MemoryWatcher<byte>(GameDataMan+0xC0);
    vars.Logt("isBossFight", vars.IsBossFight.Current.ToString());

    vars.deathCount = new MemoryWatcher<int>(GameDataMan+0x94);
    vars.deathCount.Update(game);
    vars.DisplayDeathCounter(vars.deathCount.Current);
    vars.Logt("death count", vars.deathCount.Current.ToString());

    vars.UpdateCategory = (Action)(()=>{
        
        vars.Category = 0;

        if (settings["Custom category (default)"])
        {
            vars.Category = 0;
        }
        if (settings["All bosses"])
        {
            vars.Category = 1;
        }
        else if (settings["All Base game bosses"])
        {
            vars.Category = 2;
        }
        else if (settings["All remembrances"])
        {
            vars.Category = 3;
        }
        else if (settings["All DLC Bosses"])
        {
            vars.Category = 4;
        }
        else if (settings["Main DLC bosses"])
        {
            vars.Category = 5;
        }
        
        vars.DisplayCategory(vars.Category);
    });
    
    vars.UpdateCategory();

    if (!vars.LoadSoulMem())
    {
        vars.Msgb(vars.err);
        vars.Log(vars.err);

    }        

}

update
{
    if (vars.ER == null ) 
    {
        return;
    }


    #region update category
    vars.UpdateCategory();
    #endregion

    #region update soulmemory reading
    vars.ER.TryRefresh();

    var isPlayerLoadedOld = vars.IsPlayerLoaded;
    vars.IsPlayerLoaded= vars.ER.IsPlayerLoaded();
    if (!vars.IsPlayerLoaded)
    {
        if (isPlayerLoadedOld)
        {
            vars.Logt("Player","Logged out");
        }
        return;
    } else if (!isPlayerLoadedOld)
    {
        vars.Logt("Player","Logged in");
    }


    #region update bosses' state
    var defeated = new List<uint>();
    foreach (var boss in vars.RemainingBoss)
    {
        var currentState = vars.ER.ReadEventFlag(boss);
        if (currentState)
        {
            if (!vars.Startup)
            {
                vars.DisplayPrevBossName(vars.BossesNames[boss]); // don't set boss name at first startup
            }
            vars.LastBattleWon = true;
            defeated.Add(boss);
        }
    }
    foreach(var boss in defeated)
    {
        vars.RemainingBoss.Remove(boss);
    }

    if (defeated.Count > 0)
    {
        foreach(var boss in vars.RemainingBoss)
        {
            vars.Logt("RemainingBoss", vars.BossesNames[boss]);
        }
    }
    #endregion

    #region update number defeated bosses (based on category)


    string text = (vars.BossesNames.Count - vars.RemainingBoss.Count).ToString();
    uint[] targetGroup = null;
    switch ((int)vars.Category)
    {
        case 1:// All bosses
           text+= "/" + vars.BossesNames.Count.ToString(); 
            break;
        case 2: // All base game
            targetGroup = vars.BaseGameBosses;
            break;
        case 3: // All remembrances
            targetGroup = vars.RemembranceBosses;
            break;
        case 4:// All DLC bosses
            targetGroup = vars.DLCBosses;
            break;
        case 5: // Main DLC bosses (remembrances + bayle)
            targetGroup = vars.MainDLCBosses;
            break;
        default: // custom
            break;
    }
    if (targetGroup != null)
    {
        int tempRemainingBosses = 0;
        foreach(var boss in vars.RemainingBoss)
        {
            if (targetGroup.ToList().Contains(boss))
            {
                tempRemainingBosses++;
            }
        }
        text = String.Format("{0}/{1}",targetGroup.Length - tempRemainingBosses, targetGroup.Length);
    }
    vars.DisplayDefeatedBosses(text);
    

    #endregion

    #region update inventory

    var inventory = new List<UInt32>();
    var KeyItemInvData = new int[]{ 0x5D0, 1, 384}; // offset,isKey,length

    var playerGameData = vars.ReadPointer(game,vars.GameDataMan + 0x8 );
    var equipInventoryData = vars.ReadPointer(game,playerGameData + KeyItemInvData[0]);

    var inventoryList = vars.ReadPointer(game,equipInventoryData + 0x10 + 0x10*KeyItemInvData[1] );
    var inventoryNum = vars.ReadInt(game,equipInventoryData + 0x18);

    int count = 0;
    for (int i = 0;i<KeyItemInvData[2];i++)
    {
        var itemStruct = inventoryList + (i *0X18);
        var GaItemHandle = vars.ReadInt(game,itemStruct);
        var itemID =(UInt32) vars.ReadInt(game,itemStruct + 4);
        var itemType = itemID & 0xF0000000;
        itemID = itemID & ~itemType;

        var quantity = vars.ReadInt(game,itemStruct+8);

        if (itemID <= 0x5FFFFFFF 
        && itemID != 0
        && quantity!= 0 
        && itemID != 0xFFFFFFFF 
        && GaItemHandle !=0)
        {
            inventory.Add(itemID);
            count++;
        }

        if (count> inventoryNum)
        {
            break;
        }

    }

    #region Read great runes 
    const int GODRICK_S_GREAT_RUNE = 191;
    const int GODRICK_S_GREAT_RUNE_UNPOWERED = 8148;

    const int RADAHN_S_GREAT_RUNE = 192;
    const int RADAHN_S_GREAT_RUNE_UNPOWERED = 8149;

    const int MORGOTT_S_GREAT_RUNE = 193; 
    const int MORGOTT_S_GREAT_RUNE_UNPOWERED = 8150;

    const int RYKARD_S_GREAT_RUNE = 194; 
    const int RYKARD_S_GREAT_RUNE_UNPOWERED = 8151;
    
    const int MOHG_S_GREAT_RUNE = 195; 
    const int MOHG_S_GREAT_RUNE_UNPOWERED = 8152;

    const int MALENIA_S_GREAT_RUNE = 196;
    const int MALENIA_S_GREAT_RUNE_UNPOWERED = 8153;

    const int GREAT_RUNE_OF_THE_UNBORN = 10080;
    

    int[,] gt =
    {
        {GODRICK_S_GREAT_RUNE,GODRICK_S_GREAT_RUNE_UNPOWERED },
        {RADAHN_S_GREAT_RUNE,RADAHN_S_GREAT_RUNE_UNPOWERED },
        {MORGOTT_S_GREAT_RUNE,MORGOTT_S_GREAT_RUNE_UNPOWERED },
        {RYKARD_S_GREAT_RUNE,RYKARD_S_GREAT_RUNE_UNPOWERED },
        {MOHG_S_GREAT_RUNE,MOHG_S_GREAT_RUNE_UNPOWERED },
        {MALENIA_S_GREAT_RUNE,MALENIA_S_GREAT_RUNE_UNPOWERED },
        {GREAT_RUNE_OF_THE_UNBORN,GREAT_RUNE_OF_THE_UNBORN }
    };

    int numberOfGreateRunes = 0;

    foreach (var item in inventory)
    {
        for (int i = 0;i < gt.GetLength(0);i++)
        {
            if (item== gt[i,0] || item == (gt[i,1]))
            {
                numberOfGreateRunes++;
            }
        }
    }
    vars.DisplayNumOfGreatRunes(numberOfGreateRunes);

    #endregion
    #endregion
    #endregion

    #region update death count and timer

    if (vars.IsPlayerLoaded)
    {
        vars.deathCount.Update(game);
        if (vars.deathCount.Current != vars.deathCount.Old)
        {	
            vars.Logt("death count", vars.deathCount.Current.ToString());
            vars.DisplayDeathCounter(vars.deathCount.Current);
        }	
    }
    vars.IsBossFight.Update(game);
    vars.ShouldReset = (vars.IsBossFight.Old == 0 && vars.IsBossFight.Current == 1);
    #endregion


    vars.Startup = false;
}

onReset
{
    if (!vars.ShouldReset) // means that it was reset manually
    {
        vars.Reset(false); // reset every displayed information
        vars.Logt("Manual reset", "Done");
    }
    vars.ShouldReset = false;
}
reset
{
    var shouldReset = vars.ShouldReset; // resets the timer when a new boss fight begins
	
	if (shouldReset)
    {
		vars.Logt("timer","reset");
        vars.DisplayPrevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
    }
    return shouldReset;
}


start
{
	if (vars.IsBossFight.Current == 1)
	{
        vars.Logt("timer","started");
		return true; // start timer during boss fight (called only when timer is reset)
	}
}

isLoading
{
	if (vars.IsBossFight.Current == 0)
	{
        if (vars.LastBattleWon)
        {
            vars.DisplayPreviousKillTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
            vars.LastBattleWon = false;
        }
        if (vars.IsBossFight.Old == 1)
        {
		    vars.Logt("timer","paused");
        }
		return true;
	}
}


