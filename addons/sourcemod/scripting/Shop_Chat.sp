//------------------------------------------------------------------------------
// GPL LISENCE (short)
//------------------------------------------------------------------------------
/*
 * Copyright (c) 2014 R1KO

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 * ChangeLog:
		1.0 - Release

		2.0 - Completely rewritten plugin.

		2.1 - Fixed all bugs found.
				Changed the structure of the file with colours.
				Fixed saving of player colours.
				Added informational messages.
				Added save state of punt and resumption on re-entry.
		2.2 - Renamed all quars.
				Added quare sm_shop_chat_use_prefix_file.
		2.2.1 - Added config existence checks.
		2.2.2 - Fixed bug with prefix file.
				Fixed prefix save.
				Minor fixes.
				Changed the info menu.
		2.2.3 - Fixed bug where client could be out of game 442 line
		2.2.4 - Multicolors support
		2.2.5 - Update to SM 1.11
		2.2.6 - RegPluginLibrary
			CCC support
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_functions>
#include <basecomm>
#include <clientprefs>

#include <shop>
#include <multicolors>

#tryinclude <ccc>

#define CATEGORY "Chat"
#define ITEM1 "Name Color"
#define ITEM2 "Prefix"
#define ITEM3 "Text Color"
#define COLORTAG "\x07"
#define DEFAULT_COLOR "FFFFFF"

public Plugin myinfo = 
{
	name = "[Shop] Name/Prefix/Text Color",
	description = "Grant player to buy name/prefix/text color",
	author = "R1KO, maxime1907",
	version = "2.2.8",
	url = "http://hlmod.ru"
}

#define NAME_COLOR 0
#define TEXT_COLOR 1
#define PREFIX_COLOR 2
#define PREFIX 3

Menu	
	g_hMenuColor,
	g_hMenuPref;

Cookie
	g_hCookie[4];

int	
	g_iArrayPrice[3],
	g_iArraySellPrice[3],
	g_iArrayDuration[3];
	
bool
	g_bUsePrefixFile,
	g_bUsed[MAXPLAYERS + 1][3];
	
char 
	g_sColors[MAXPLAYERS+1][3][15],
	g_sPrefix[MAXPLAYERS + 1][100];

int	
	g_iTypeMenu[MAXPLAYERS+1];

ItemId id[3];

bool g_bLate = false;
bool g_bCCC = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Shop_Chat");
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("Shop_Chat.phrases");

	ConVar hCvar;
	
	((hCvar = CreateConVar("sm_shop_chat_name_price", "1000", "Name color price"))).AddChangeHook(NamePriceChange);
	g_iArrayPrice[NAME_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_name_sellprice", "1000", "Name selling price. (Disable selling: -1)"))).AddChangeHook(NameSellPriceChange);
	g_iArraySellPrice[NAME_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_name_duration", "86400", "Duration of use of the colored name"))).AddChangeHook(NameDurationChange);
	g_iArrayDuration[NAME_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_text_price", "1000", "Chat color price."))).AddChangeHook(TextPriceChange);
	g_iArrayPrice[TEXT_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_text_sellprice", "1000", "Chat selling price. (Disable selling: -1)"))).AddChangeHook(TextSellPriceChange);
	g_iArraySellPrice[TEXT_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_text_duration", "86400", "Duration of use of the colored chat"))).AddChangeHook(TextDurationChange);
	g_iArrayDuration[TEXT_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_prefix_price", "1000", "Tag and Tag color price"))).AddChangeHook(PrefixPriceChange);
	g_iArrayPrice[PREFIX_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_prefix_sellprice", "1000", "Tag and Tag color selling price. (Disable selling: -1)"))).AddChangeHook(PrefixSellPriceChange);
	g_iArraySellPrice[PREFIX_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_prefix_duration", "86400", "Duration of use of the Tag and its color"))).AddChangeHook(PrefixDurationChange);
	g_iArrayDuration[PREFIX_COLOR] = hCvar.IntValue;
	
	((hCvar = CreateConVar("sm_shop_chat_use_prefix_file", "0", "Allow only Tags from the config file to be selected, otherwise - can specify any (1 - On, 0 - Off)"))).AddChangeHook(UsePrefixFileChange);
	g_bUsePrefixFile = hCvar.BoolValue;

	AutoExecConfig(true, _, "shop");

	g_hCookie[NAME_COLOR] = new Cookie("Shop Name Color", "Name Color", CookieAccess_Public);
	g_hCookie[TEXT_COLOR] = new Cookie("Shop Text Color", "Text Color", CookieAccess_Public);
	g_hCookie[PREFIX_COLOR] = new Cookie("Shop Prefix Color", "Prefix Color", CookieAccess_Public);
	g_hCookie[PREFIX] = new Cookie("Shop Prefix", "Prefix", CookieAccess_Public);

	RegConsoleCmd("sm_shopcolor", MyColor_CMD);
	RegConsoleCmd("sm_shoptag", MyPref_CMD);

	if (g_bLate && Shop_IsStarted())
	{
		Shop_Started();
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "ccc"))
	{
		g_bCCC = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "ccc"))
	{
		g_bCCC = false;
	}
}

public void NamePriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayPrice[NAME_COLOR] = hCvar.IntValue;
	if(id[NAME_COLOR] != INVALID_ITEM) 
		Shop_SetItemPrice(id[NAME_COLOR], g_iArrayPrice[NAME_COLOR]);
}

public void NameSellPriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArraySellPrice[NAME_COLOR] = hCvar.IntValue;
	if(id[NAME_COLOR] != INVALID_ITEM) Shop_SetItemSellPrice(id[NAME_COLOR], g_iArraySellPrice[NAME_COLOR]);
}

public void NameDurationChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayDuration[NAME_COLOR] = hCvar.IntValue;
	if(id[NAME_COLOR] != INVALID_ITEM) Shop_SetItemValue(id[NAME_COLOR], g_iArrayDuration[NAME_COLOR]);
}

public void TextPriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayPrice[TEXT_COLOR] = hCvar.IntValue;
	if(id[TEXT_COLOR] != INVALID_ITEM) 
		Shop_SetItemPrice(id[TEXT_COLOR], g_iArrayPrice[TEXT_COLOR]);
}

public void TextSellPriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArraySellPrice[TEXT_COLOR] = hCvar.IntValue;
	if(id[TEXT_COLOR] != INVALID_ITEM) 
		Shop_SetItemSellPrice(id[TEXT_COLOR], g_iArraySellPrice[TEXT_COLOR]);
}

public void TextDurationChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayDuration[TEXT_COLOR] = hCvar.IntValue;
	if(id[TEXT_COLOR] != INVALID_ITEM) 
		Shop_SetItemValue(id[TEXT_COLOR], g_iArrayDuration[TEXT_COLOR]);
}

public void PrefixPriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayPrice[PREFIX_COLOR] = hCvar.IntValue;
	if(id[PREFIX_COLOR] != INVALID_ITEM) 
		Shop_SetItemPrice(id[PREFIX_COLOR], g_iArrayPrice[PREFIX_COLOR]);
}

public void PrefixSellPriceChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArraySellPrice[PREFIX_COLOR] = hCvar.IntValue;
	if(id[PREFIX_COLOR] != INVALID_ITEM) 
		Shop_SetItemSellPrice(id[PREFIX_COLOR], g_iArraySellPrice[PREFIX_COLOR]);
}

public void PrefixDurationChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_iArrayDuration[PREFIX_COLOR] = hCvar.IntValue;
	if(id[PREFIX_COLOR] != INVALID_ITEM) 
		Shop_SetItemValue(id[PREFIX_COLOR], g_iArrayDuration[PREFIX_COLOR]);
}

public void UsePrefixFileChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	g_bUsePrefixFile = hCvar.BoolValue;
	CreatePrefixMenu();
}

public void OnConfigsExecuted()
{
	ParseCFG();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, "Chat", "", OnCategoryDisplay);

	if (Shop_StartItem(category_id, ITEM1))
	{
		Shop_SetInfo("Name color", "", g_iArrayPrice[NAME_COLOR], g_iArraySellPrice[NAME_COLOR], Item_Togglable, g_iArrayDuration[NAME_COLOR]);
		Shop_SetCallbacks(OnNameItemRegistered, OnNameColorUsed, _, OnItemDisplay);
		Shop_EndItem();
	}
	if (Shop_StartItem(category_id, ITEM3))
	{
		Shop_SetInfo("Text color", "", g_iArrayPrice[TEXT_COLOR], g_iArraySellPrice[TEXT_COLOR], Item_Togglable, g_iArrayDuration[TEXT_COLOR]);
		Shop_SetCallbacks(OnTextItemRegistered, OnTextColorUsed, _, OnItemDisplay);
		Shop_EndItem();
	}
	if (Shop_StartItem(category_id, ITEM2))
	{
		Shop_SetInfo("Tag and Tag color", "", g_iArrayPrice[PREFIX_COLOR], g_iArraySellPrice[PREFIX_COLOR], Item_Togglable, g_iArrayDuration[PREFIX_COLOR]);
		Shop_SetCallbacks(OnPrefixItemRegistered, OnPrefixUsed, _, OnItemDisplay);
		Shop_EndItem();
	}
}

public void OnNameItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id[NAME_COLOR] = item_id;
}

public void OnTextItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id[TEXT_COLOR] = item_id;
}

public void OnPrefixItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id[PREFIX_COLOR] = item_id;
}

public bool OnCategoryDisplay(int iClient, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen, ShopMenu menu)
{
	FormatEx(buffer, maxlen, "%T", "Shop Chat Category", iClient);
	return true;
}

public bool OnItemDisplay(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	if(item_id == id[NAME_COLOR])
		FormatEx(buffer, maxlen, "%T", "Shop Chat Name Color", iClient);
	else if(item_id == id[TEXT_COLOR])
		FormatEx(buffer, maxlen, "%T", "Shop Chat Text Color", iClient);
	else if(item_id == id[PREFIX_COLOR])
		FormatEx(buffer, maxlen, "%T", "Shop Chat Tag And Color", iClient);
	else
		return false;

	return true;
}

public void Shop_OnAuthorized(int iClient)
{
	for(int i = 0; i < 3; i++)
	{
		g_sColors[iClient][i][0] = '\0';
		g_bUsed[iClient][i] = false;
		if(Shop_IsClientHasItem(iClient, id[i])) 
			g_bUsed[iClient][i] = Shop_IsClientItemToggled(iClient, id[i]);
	}
	g_sPrefix[iClient][0] = '\0';
}

public ShopAction OnNameColorUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][NAME_COLOR] = false;
		return Shop_UseOff;
	}

	g_hCookie[NAME_COLOR].Get(iClient, g_sColors[iClient][NAME_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][NAME_COLOR], sizeof(g_sColors[][]));
	g_bUsed[iClient][NAME_COLOR] = true;
	CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Name Color Hint");

	return Shop_UseOn;
}

public ShopAction OnTextColorUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][TEXT_COLOR] = false;
		return Shop_UseOff;
	}

	g_hCookie[TEXT_COLOR].Get(iClient, g_sColors[iClient][TEXT_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][TEXT_COLOR], sizeof(g_sColors[][]));
	g_bUsed[iClient][TEXT_COLOR] = true;
	CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Text Color Hint");

	return Shop_UseOn;
}

public ShopAction OnPrefixUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][PREFIX_COLOR] = false;
		return Shop_UseOff;
	}

	g_hCookie[PREFIX_COLOR].Get(iClient, g_sColors[iClient][PREFIX_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][PREFIX_COLOR], sizeof(g_sColors[][]));

	g_hCookie[PREFIX].Get(iClient, g_sPrefix[iClient], sizeof(g_sPrefix[]));
	if(g_sPrefix[iClient][0] == '\0') strcopy(g_sPrefix[iClient], sizeof(g_sPrefix[]), "Tag");

	g_bUsed[iClient][PREFIX_COLOR] = true;
	CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Tag Hint");

	return Shop_UseOn;
}

stock void EditColor(char[] sColor, int len)
{
	Format(sColor, len, "%s%s", COLORTAG, (StringToInt(sColor, 16) != 0 || StrEqual(sColor, "000000")) ? sColor:DEFAULT_COLOR);
}

stock void ParseCFG()
{
	CheckCloseHandle(g_hMenuColor);
	
	char sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/shop/chat_colors.cfg");	
	
	if(!FileExists(sBuffer)) 
		SetFailState("File not found: %s", sBuffer);
		
	g_hMenuColor = new Menu(MenuHandler_Color, MENU_ACTIONS_DEFAULT|MenuAction_Display);
	g_hMenuColor.ExitBackButton = true;
	g_hMenuColor.SetTitle("%T", "Shop Chat Choose Color", LANG_SERVER);

	SMCParser ConfigParser = new SMCParser();
	ConfigParser.OnEnterSection = ReadConfig_NewSection;
	ConfigParser.OnKeyValue = ReadConfig_KeyValue;
	ConfigParser.OnLeaveSection = ReadConfig_EndSection;

	SMCError err = ConfigParser.ParseFile(sBuffer);

	if (err != SMCError_Okay)
	{
		char buffer[64];
		if (ConfigParser.GetErrorString(err, buffer, sizeof(buffer)))
			PrintToServer(buffer);
		else 
			PrintToServer("Fatal parse error");
	}
	
	delete ConfigParser;
	CreatePrefixMenu();
}

public SMCResult ReadConfig_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	return SMCParse_Continue;
}

public SMCResult ReadConfig_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_hMenuColor.AddItem(value, key);
	return SMCParse_Continue;
}

public SMCResult ReadConfig_EndSection(SMCParser smc)
{
	return SMCParse_Continue;
}

stock void CreatePrefixMenu()
{
	CheckCloseHandle(g_hMenuPref);

	g_hMenuPref = new Menu(MenuHandler_Pref, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);

	if(g_bUsePrefixFile)
	{
		g_hMenuPref.ExitBackButton = true;
		g_hMenuPref.SetTitle("%T", "Shop Chat Choose Tag", LANG_SERVER);
		
		char sBuffer[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/shop/chat_prefix.cfg");
		if(!FileExists(sBuffer)) SetFailState("File not found: %s", sBuffer);
		File hFile = OpenFile(sBuffer, "r");
		
		if (hFile != null)
		{
			while (!hFile.EndOfFile() && hFile.ReadLine(sBuffer, sizeof(sBuffer)))
			{
				TrimString(sBuffer);
			
				if (sBuffer[0]) g_hMenuPref.AddItem(sBuffer, sBuffer);
			}
		} else SetFailState("Failed to open file: %s", sBuffer);

		delete hFile;
		
		if(g_hMenuPref.ItemCount == 0) g_hMenuPref.AddItem("", "Нет доступных префиксов", ITEMDRAW_DISABLED);
	} else
	{
		g_hMenuPref.ExitButton = true;
		g_hMenuPref.SetTitle("%T", "Shop Chat Set Tag Help", LANG_SERVER);
		g_hMenuPref.AddItem("", "Back");
	}
}

public Action MyColor_CMD(int iClient, int args)
{
	if(iClient > 0) 
	{
		if(g_bCCC)
		{
			#if defined _ccc_included
			if(CCC_IsClientEnabled(iClient))
			{
				CReplyToCommand(iClient, "{green}[Shop] {default}%t", "Shop Chat Use CCC");
				return Plugin_Handled;
			}
			#endif
		}

		if(g_bUsed[iClient][NAME_COLOR] || g_bUsed[iClient][TEXT_COLOR] || g_bUsed[iClient][PREFIX_COLOR])
			SendChatMenu(iClient);
		else 
			CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Buy To Open Menu");
	}
	
	return Plugin_Handled;
}

stock void SendChatMenu(int iClient)
{
	char sBuffer[64];
	Menu hChatMenu = new Menu(MenuHandler_ChatMenu);
	hChatMenu.SetTitle("%T\n \n", "Shop Chat Menu Title", iClient);
	hChatMenu.ExitButton = true;
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Shop Chat Name Color", iClient);
	hChatMenu.AddItem("", sBuffer, (g_bUsed[iClient][NAME_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Shop Chat Text Color", iClient);
	hChatMenu.AddItem("", sBuffer, (g_bUsed[iClient][TEXT_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Shop Chat Tag Color", iClient);
	hChatMenu.AddItem("", sBuffer, (g_bUsed[iClient][PREFIX_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Shop Chat Tag", iClient);
	hChatMenu.AddItem("", sBuffer, (g_bUsed[iClient][PREFIX_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	hChatMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_ChatMenu(Menu hMenu, MenuAction action, int iClient, int option) 
{
 	if (action == MenuAction_Select)
	{
		if(option == 3) 
			g_hMenuPref.Display(iClient, MENU_TIME_FOREVER);
		else
		{
			g_iTypeMenu[iClient] = option;
			g_hMenuColor.Display(iClient, MENU_TIME_FOREVER);
		}
	} 
	else if (action == MenuAction_End) 
		delete hMenu;
		
	return 0;
}

public int MenuHandler_Color(Menu hMenu, MenuAction action, int iClient, int option) 
{
 	if (action == MenuAction_Select)
	{
		hMenu.GetItem(option, g_sColors[iClient][g_iTypeMenu[iClient]], sizeof(g_sColors[][]));
		(g_hCookie[g_iTypeMenu[iClient]]).Set(iClient, g_sColors[iClient][g_iTypeMenu[iClient]]);
		EditColor(g_sColors[iClient][g_iTypeMenu[iClient]], sizeof(g_sColors[][]));
		SendChatMenu(iClient);
	} 
	else if (action == MenuAction_Cancel && option == MenuCancel_ExitBack) 
		SendChatMenu(iClient);
	else if (action == MenuAction_Display)
	{
		char sTitle[128];
		FormatEx(sTitle, sizeof(sTitle), "%T", "Shop Chat Choose Color", iClient);
		view_as<Panel>(option).SetTitle(sTitle);
	}
		
	return 0;
}

public int MenuHandler_Pref(Menu hMenu, MenuAction action, int iClient, int option) 
{
	if (action == MenuAction_Select)
	{
		if(!g_bUsePrefixFile) 
			SendChatMenu(iClient);
		else
		{
			hMenu.GetItem(option, g_sPrefix[iClient], sizeof(g_sPrefix[]));
			g_hCookie[PREFIX].Set(iClient, g_sPrefix[iClient]);
			CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Tag Set", g_sPrefix[iClient]);
			SendChatMenu(iClient);
		}
	}
	else if (action == MenuAction_Cancel && option == MenuCancel_ExitBack) 
		SendChatMenu(iClient);
	else if (action == MenuAction_Display)
	{
		char sTitle[512];
		FormatEx(sTitle, sizeof(sTitle), "%T", g_bUsePrefixFile ? "Shop Chat Choose Tag" : "Shop Chat Set Tag Help", iClient);
		view_as<Panel>(option).SetTitle(sTitle);
	}
	else if (action == MenuAction_DisplayItem)
	{
		char sInfo[100];
		hMenu.GetItem(option, sInfo, sizeof(sInfo));
		if(sInfo[0] == '\0')
		{
			char sDisplay[128];
			FormatEx(sDisplay, sizeof(sDisplay), "%T", g_bUsePrefixFile ? "Shop Chat No Tags" : "Shop Chat Back", iClient);
			return RedrawMenuItem(sDisplay);
		}
	}
	
	return 0;
}

public Action MyPref_CMD(int iClient, int args)
{
	if(iClient > 0)
	{
		if(g_bCCC)
		{
			#if defined _ccc_included
			if(CCC_IsClientEnabled(iClient))
			{
				CReplyToCommand(iClient, "{green}[Shop] {default}%t", "Shop Chat Use CCC");
				return Plugin_Handled;
			}
			#endif
		}

		if(g_bUsed[iClient][PREFIX_COLOR])
		{
			if(!g_bUsePrefixFile)
			{
				GetCmdArgString(g_sPrefix[iClient], sizeof(g_sPrefix[]));
				if(g_sPrefix[iClient][0] == '\0') 
					strcopy(g_sPrefix[iClient], sizeof(g_sPrefix[]), "Префикс");
					
				g_hCookie[PREFIX].Set(iClient, g_sPrefix[iClient]);
				CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Tag Set", g_sPrefix[iClient]);
			} 
			else 
				CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Command Unavailable");
		} 
		else 
			CPrintToChat(iClient, "{green}[Shop] {default}%t", "Shop Chat Buy Tag");
	}
	
	return Plugin_Handled;
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] sArgs)
{
	if(iClient > 0 && IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		#if defined _ccc_included
		if(g_bCCC && CCC_IsClientEnabled(iClient))
			return Plugin_Continue;
		#endif

		if(BaseComm_IsClientGagged(iClient)) 
			return Plugin_Handled;
			
		if(g_bUsed[iClient][NAME_COLOR] || g_bUsed[iClient][TEXT_COLOR] || g_bUsed[iClient][PREFIX_COLOR])
		{
			if(sArgs[1] == '@' || sArgs[1] == '/') return Plugin_Continue;

			char sText[192];
			strcopy(sText, sizeof(sText), sArgs);
			TrimString(sText);
			StripQuotes(sText);
			
			int iTeam = GetClientTeam(iClient);
			char sNameColor[80], sTextColor[210], sPrefix[120];
				
			FormatEx(sNameColor, sizeof(sNameColor), "%s%N", (g_bUsed[iClient][NAME_COLOR]) ? g_sColors[iClient][NAME_COLOR]:"\x03", iClient);
			FormatEx(sTextColor, sizeof(sTextColor), "\x01: %s%s", (g_bUsed[iClient][TEXT_COLOR]) ? g_sColors[iClient][TEXT_COLOR]:"", sText);
				
			if(g_bUsed[iClient][PREFIX_COLOR]) FormatEx(sPrefix, sizeof(sPrefix), "%s%s ", g_sColors[iClient][PREFIX_COLOR], g_sPrefix[iClient]);
			else sPrefix[0] = '\0';

			if(StrEqual(command, "say"))
			{
				FormatEx(sText, sizeof(sText), "\x01%s%s%s%s", (iTeam < 2) ? "*SPECTATOR* ":((IsPlayerAlive(iClient)) ? "":"*DEAD* "), sPrefix, sNameColor, sTextColor);
				Handle h = StartMessageAll("SayText2");
				if (h != null) 
				{ 
					BfWrite bf = UserMessageToBfWrite(h);
					bf.WriteByte(iClient); 
					bf.WriteByte(true);
					bf.WriteString(sText); 
					EndMessage();
				}
			} 
			else if(StrEqual(command, "say_team"))
			{
				FormatEx(sText, sizeof(sText), "\x01%s %s%s%s%s", (iTeam < 2) ? "(Spectator)":((iTeam == 2) ? "(Terrorist)":"(Counter-Terrorist)"), (iTeam < 2) ? "":((IsPlayerAlive(iClient)) ? "":"*DEAD* "), sPrefix, sNameColor, sTextColor);
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam) 
					{
						Handle h = StartMessageOne("SayText2", i);
						if (h != null) 
						{ 
							BfWrite bf = UserMessageToBfWrite(h);
							bf.WriteByte(iClient); 
							bf.WriteByte(true);
							bf.WriteString(sText); 
							EndMessage();
						}
					}
				}
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

stock void CheckCloseHandle(Handle &handle)
{
	if (handle != null)
	{
		delete handle;
	}
}
