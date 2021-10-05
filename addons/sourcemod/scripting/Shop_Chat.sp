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
		1.0	- 	Релиз

		2.0	- 	Полностю переписан плагин.

		2.1	-	Исправлены все найденые ошибки.
				Изменена структура файла с цветами.
				Иправлено сохранение цветов игрока.
				Добавлены информационные сообщения.
				Доавблено сохранение состояния пунтка и возобновление при перезаходе.
		2.2	-	Переименованы все квары.
				Добавлен квар sm_shop_chat_use_prefix_file.
		2.2.1 -	Добавлены проверки на существование конфигов.
		2.2.2 -	Исправлена ошибка с файлом префиксов.
				Исправлено сохранение префикса.
				Мелкие фиксы.
				Изменено меню информации.
		2.2.3 - Исправлена ошибка, когда клиент мог быть не в игре 442 строка
*/

#pragma semicolon 1
#include <sourcemod>
#include <shop>
#include <sdktools_functions>
#include <basecomm>
#include <clientprefs>

#define CATEGORY "Chat"
#define ITEM1 "Name Color"
#define ITEM2 "Prefix"
#define ITEM3 "Text Color"
#define COLORTAG "\x07"
#define DEFAULT_COLOR "FFFFFF"

public Plugin:myinfo = 
{
	name = "[Shop] Name/Prefix/Text Color",
	description = "Grant player to buy name/prefix/text color",
	author = "R1KO",
	version = "2.2.3",
	url = "http://hlmod.ru"
};

#define NAME_COLOR 0
#define TEXT_COLOR 1
#define PREFIX_COLOR 2
#define PREFIX 3

new	Handle:g_hMenuColor,
	Handle:g_hMenuPref,
	Handle:g_hCookie[4];

new	g_iArrayPrice[3],
	g_iArraySellPrice[3],
	g_iArrayDuration[3],
	bool:g_bUsePrefixFile;

new bool:g_bUsed[MAXPLAYERS+1][3],
	String:g_sColors[MAXPLAYERS+1][3][15],
	String:g_sPrefix[MAXPLAYERS+1][100],
	g_iTypeMenu[MAXPLAYERS+1];

new ItemId:id[3];

public OnPluginStart()
{
	new Handle:hCvar;
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_name_price", "1000", "Цена цвета ника.")), NamePriceChange);
	g_iArrayPrice[NAME_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_name_sellprice", "1000", "Цена продажи цвета ника. (Запретить продажу: -1)")), NameSellPriceChange);
	g_iArraySellPrice[NAME_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_name_duration", "86400", "Длительность использования цвета ника.")), NameDurationChange);
	g_iArrayDuration[NAME_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_text_price", "1000", "Цена цвета сообщений.")), TextPriceChange);
	g_iArrayPrice[TEXT_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_text_sellprice", "1000", "Цена продажи цвета сообщений. (Запретить продажу: -1)")), TextSellPriceChange);
	g_iArraySellPrice[TEXT_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_text_duration", "86400", "Длительность использования цвета сообщений.")), TextDurationChange);
	g_iArrayDuration[TEXT_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_prefix_price", "1000", "Цена префикса и его цвета.")), PrefixPriceChange);
	g_iArrayPrice[PREFIX_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_prefix_sellprice", "1000", "Цена продажи префикса и его цвета. (Запретить продажу: -1)")), PrefixSellPriceChange);
	g_iArraySellPrice[PREFIX_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_prefix_duration", "86400", "Длительность использования префикса и его цвета.")), PrefixDurationChange);
	g_iArrayDuration[PREFIX_COLOR] = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_chat_use_prefix_file", "0", "Разрешить выбрать только префиксы из списка, иначе - сможет указать любой (1 - Вкл., 0 - Выкл)")), UsePrefixFileChange);
	g_bUsePrefixFile = GetConVarBool(hCvar);
	
	CloseHandle(hCvar);

	AutoExecConfig(true, _, "shop");

	g_hCookie[NAME_COLOR] = RegClientCookie("Shop Name Color", "Name Color", CookieAccess_Public);
	g_hCookie[TEXT_COLOR] = RegClientCookie("Shop Text Color", "Text Color", CookieAccess_Public);
	g_hCookie[PREFIX_COLOR] = RegClientCookie("Shop Prefix Color", "Prefix Color", CookieAccess_Public);
	g_hCookie[PREFIX] = RegClientCookie("Shop Prefix", "Prefix", CookieAccess_Public);

	RegConsoleCmd("sm_color", MyColor_CMD);
	RegConsoleCmd("sm_myprefix", MyPref_CMD);	

	if (Shop_IsStarted()) Shop_Started();
}

public NamePriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayPrice[NAME_COLOR] = GetConVarInt(hCvar);
	if(id[NAME_COLOR] != INVALID_ITEM) Shop_SetItemPrice(id[NAME_COLOR], g_iArrayPrice[NAME_COLOR]);
}

public NameSellPriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArraySellPrice[NAME_COLOR] = GetConVarInt(hCvar);
	if(id[NAME_COLOR] != INVALID_ITEM) Shop_SetItemSellPrice(id[NAME_COLOR], g_iArraySellPrice[NAME_COLOR]);
}

public NameDurationChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayDuration[NAME_COLOR] = GetConVarInt(hCvar);
	if(id[NAME_COLOR] != INVALID_ITEM) Shop_SetItemValue(id[NAME_COLOR], g_iArrayDuration[NAME_COLOR]);
}

public TextPriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayPrice[TEXT_COLOR] = GetConVarInt(hCvar);
	if(id[TEXT_COLOR] != INVALID_ITEM) Shop_SetItemPrice(id[TEXT_COLOR], g_iArrayPrice[TEXT_COLOR]);
}

public TextSellPriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArraySellPrice[TEXT_COLOR] = GetConVarInt(hCvar);
	if(id[TEXT_COLOR] != INVALID_ITEM) Shop_SetItemSellPrice(id[TEXT_COLOR], g_iArraySellPrice[TEXT_COLOR]);
}

public TextDurationChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayDuration[TEXT_COLOR] = GetConVarInt(hCvar);
	if(id[TEXT_COLOR] != INVALID_ITEM) Shop_SetItemValue(id[TEXT_COLOR], g_iArrayDuration[TEXT_COLOR]);
}

public PrefixPriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayPrice[PREFIX_COLOR] = GetConVarInt(hCvar);
	if(id[PREFIX_COLOR] != INVALID_ITEM) Shop_SetItemPrice(id[PREFIX_COLOR], g_iArrayPrice[PREFIX_COLOR]);
}

public PrefixSellPriceChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArraySellPrice[PREFIX_COLOR] = GetConVarInt(hCvar);
	if(id[PREFIX_COLOR] != INVALID_ITEM) Shop_SetItemSellPrice(id[PREFIX_COLOR], g_iArraySellPrice[PREFIX_COLOR]);
}

public PrefixDurationChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_iArrayDuration[PREFIX_COLOR] = GetConVarInt(hCvar);
	if(id[PREFIX_COLOR] != INVALID_ITEM) Shop_SetItemValue(id[PREFIX_COLOR], g_iArrayDuration[PREFIX_COLOR]);
}

public UsePrefixFileChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	g_bUsePrefixFile = GetConVarBool(hCvar);
	CreatePrefixMenu();
}

public OnConfigsExecuted() ParseCFG();

public OnPluginEnd() Shop_UnregisterMe();

public Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, "Чат", "");

	if (Shop_StartItem(category_id, ITEM1))
	{
		Shop_SetInfo("Цвет ника", "", g_iArrayPrice[NAME_COLOR], g_iArraySellPrice[NAME_COLOR], Item_Togglable, g_iArrayDuration[NAME_COLOR]);
		Shop_SetCallbacks(OnNameItemRegistered, OnNameColorUsed);
		Shop_EndItem();
	}
	if (Shop_StartItem(category_id, ITEM3))
	{
		Shop_SetInfo("Цвет текста", "", g_iArrayPrice[TEXT_COLOR], g_iArraySellPrice[TEXT_COLOR], Item_Togglable, g_iArrayDuration[TEXT_COLOR]);
		Shop_SetCallbacks(OnTextItemRegistered, OnTextColorUsed);
		Shop_EndItem();
	}
	if (Shop_StartItem(category_id, ITEM2))
	{
		Shop_SetInfo("Титул и его цвет", "", g_iArrayPrice[PREFIX_COLOR], g_iArraySellPrice[PREFIX_COLOR], Item_Togglable, g_iArrayDuration[PREFIX_COLOR]);
		Shop_SetCallbacks(OnPrefixItemRegistered, OnPrefixUsed);
		Shop_EndItem();
	}
}

public OnNameItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id) id[NAME_COLOR] = item_id;
public OnTextItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id) id[TEXT_COLOR] = item_id;
public OnPrefixItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id) id[PREFIX_COLOR] = item_id;

public Shop_OnAuthorized(iClient)
{
	for(new i=0; i<3; i++)
	{
		g_sColors[iClient][i][0] = '\0';
		g_bUsed[iClient][i] = false;
		if(Shop_IsClientHasItem(iClient, id[i])) g_bUsed[iClient][i] = Shop_IsClientItemToggled(iClient, id[i]);
	}
	g_sPrefix[iClient][0] = '\0';
}

public ShopAction:OnNameColorUsed(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][NAME_COLOR] = false;
		return Shop_UseOff;
	}

	GetClientCookie(iClient, g_hCookie[NAME_COLOR], g_sColors[iClient][NAME_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][NAME_COLOR], sizeof(g_sColors[][]));
	g_bUsed[iClient][NAME_COLOR] = true;
	PrintToChat(iClient, "\x04[Shop] \x01Чтобы выбрать цвет ника введите в чат \x04!color");

	return Shop_UseOn;
}

public ShopAction:OnTextColorUsed(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][TEXT_COLOR] = false;
		return Shop_UseOff;
	}

	GetClientCookie(iClient, g_hCookie[TEXT_COLOR], g_sColors[iClient][TEXT_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][TEXT_COLOR], sizeof(g_sColors[][]));
	g_bUsed[iClient][TEXT_COLOR] = true;
	PrintToChat(iClient, "\x04[Shop] \x01Чтобы выбрать цвет текста введите в чат \x04!color");

	return Shop_UseOn;
}

public ShopAction:OnPrefixUsed(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_bUsed[iClient][PREFIX_COLOR] = false;
		return Shop_UseOff;
	}

	GetClientCookie(iClient, g_hCookie[PREFIX_COLOR], g_sColors[iClient][PREFIX_COLOR], sizeof(g_sColors[][]));
	EditColor(g_sColors[iClient][PREFIX_COLOR], sizeof(g_sColors[][]));

	GetClientCookie(iClient, g_hCookie[PREFIX], g_sPrefix[iClient], sizeof(g_sPrefix[]));
	if(g_sPrefix[iClient][0] == '\0') strcopy(g_sPrefix[iClient], sizeof(g_sPrefix[]), "Префикс");

	g_bUsed[iClient][PREFIX_COLOR] = true;
	PrintToChat(iClient, "\x04[Shop] \x01Чтобы выбрать префикс и его цвет введите в чат \x04!color");

	return Shop_UseOn;
}

stock String:EditColor(String:sColor[], len) Format(sColor, len, "%s%s", COLORTAG, (StringToInt(sColor, 16) != 0 || StrEqual(sColor, "000000")) ? sColor:DEFAULT_COLOR);

ParseCFG()
{
	CheckCloseHandle(g_hMenuColor);
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/shop/chat_colors.cfg");	
	
	if(!FileExists(sBuffer)) SetFailState("Не найден файл %s", sBuffer);
	g_hMenuColor = CreateMenu(MenuHandler_Color);
	SetMenuExitBackButton(g_hMenuColor, true);
	SetMenuTitle(g_hMenuColor, "Выберите цвет:");

	new Handle:ConfigParser = SMC_CreateParser();
	SMC_SetReaders(ConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);

	new SMCError:err = SMC_ParseFile(ConfigParser, sBuffer);

	if (err != SMCError_Okay)
	{
		decl String:buffer[64];
		if (SMC_GetErrorString(err, buffer, sizeof(buffer))) PrintToServer(buffer);
		else PrintToServer("Fatal parse error");
	}
	CloseHandle(ConfigParser);
	CreatePrefixMenu();
}

public SMCResult:ReadConfig_NewSection(Handle:smc, const String:name[], bool:opt_quotes) return SMCParse_Continue;

public SMCResult:ReadConfig_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	AddMenuItem(g_hMenuColor, value, key);
	return SMCParse_Continue;
}

public SMCResult:ReadConfig_EndSection(Handle:smc) return SMCParse_Continue;

CreatePrefixMenu()
{
	CheckCloseHandle(g_hMenuPref);

	g_hMenuPref = CreateMenu(MenuHandler_Pref);

	if(g_bUsePrefixFile)
	{
		SetMenuExitBackButton(g_hMenuPref, true);
		SetMenuTitle(g_hMenuPref, "Выберите префикс:\n \n");
		
		decl String:sBuffer[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/shop/chat_prefix.cfg");
		if(!FileExists(sBuffer)) SetFailState("Не найден файл %s", sBuffer);
		new Handle:hFile = OpenFile(sBuffer, "r");
		
		if (hFile != INVALID_HANDLE)
		{
			while (!IsEndOfFile(hFile) && ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
			{
				TrimString(sBuffer);
			
				if (sBuffer[0]) AddMenuItem(g_hMenuPref, sBuffer, sBuffer);
			}
		} else SetFailState("Не удалось открыть файл %s", sBuffer);

		CloseHandle(hFile);
		
		if(GetMenuItemCount(g_hMenuPref) == 0) AddMenuItem(g_hMenuPref, "", "Нет доступных префиксов", ITEMDRAW_DISABLED);
	} else
	{
		SetMenuExitButton(g_hMenuPref, true);
		SetMenuTitle(g_hMenuPref, "Для установки префикса\nвведите в консоль:\n \nsm_myprefix \"ваш префикс\"\n \nЛибо в чат:\n \n!myprefix \"ваш префикс\"\n \n");
		AddMenuItem(g_hMenuPref, "", "Назад");
	}
}

public Action:MyColor_CMD(iClient, args)
{
	if(iClient > 0) 
	{
		if(g_bUsed[iClient][NAME_COLOR] || g_bUsed[iClient][TEXT_COLOR] || g_bUsed[iClient][PREFIX_COLOR]) SendChatMenu(iClient);
		else PrintToChat(iClient, "\x04[Shop] \x01Купите бонусы в Shop, чтобы открыть это меню!");
	}
	return Plugin_Handled;
}

SendChatMenu(iClient)
{
	new Handle:hChatMenu = CreateMenu(MenuHandler_ChatMenu);
	SetMenuTitle(hChatMenu, "Управление чатом\n \n");
	SetMenuExitButton(hChatMenu, true);
	AddMenuItem(hChatMenu, "", "Цвет ника", (g_bUsed[iClient][NAME_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddMenuItem(hChatMenu, "", "Цвет текста", (g_bUsed[iClient][TEXT_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddMenuItem(hChatMenu, "", "Цвет префикса", (g_bUsed[iClient][PREFIX_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddMenuItem(hChatMenu, "", "Префикс", (g_bUsed[iClient][PREFIX_COLOR]) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	DisplayMenu(hChatMenu, iClient, MENU_TIME_FOREVER);
}

public MenuHandler_ChatMenu(Handle:hMenu, MenuAction:action, iClient, option) 
{
 	if (action == MenuAction_Select)
	{
		if(option == 3) DisplayMenu(g_hMenuPref, iClient, MENU_TIME_FOREVER);
		else
		{
			g_iTypeMenu[iClient] = option;
			DisplayMenu(g_hMenuColor, iClient, MENU_TIME_FOREVER);
		}
	} else if (action == MenuAction_End) CloseHandle(hMenu);
}

public MenuHandler_Color(Handle:hMenu, MenuAction:action, iClient, option) 
{
 	if (action == MenuAction_Select)
	{
		GetMenuItem(hMenu, option, g_sColors[iClient][g_iTypeMenu[iClient]], sizeof(g_sColors[][]));
		SetClientCookie(iClient, g_hCookie[g_iTypeMenu[iClient]], g_sColors[iClient][g_iTypeMenu[iClient]]);
		EditColor(g_sColors[iClient][g_iTypeMenu[iClient]], sizeof(g_sColors[][]));
		SendChatMenu(iClient);
	} else if (action == MenuAction_Cancel && option == MenuCancel_ExitBack) SendChatMenu(iClient);
}

public MenuHandler_Pref(Handle:hMenu, MenuAction:action, iClient, option) 
{
	if (action == MenuAction_Select)
	{
		if(!g_bUsePrefixFile) SendChatMenu(iClient);
		else
		{
			GetMenuItem(hMenu, option, g_sPrefix[iClient], sizeof(g_sPrefix[]));
			SetClientCookie(iClient, g_hCookie[PREFIX], g_sPrefix[iClient]);
			PrintToChat(iClient, "\x04[Shop] \x01Вы установили себе префикс: \x04%s", g_sPrefix[iClient]);
			SendChatMenu(iClient);
		}
	} else if (action == MenuAction_Cancel && option == MenuCancel_ExitBack) SendChatMenu(iClient);
}

public Action:MyPref_CMD(iClient, args)
{
	if(iClient > 0)
	{
		if(g_bUsed[iClient][PREFIX_COLOR])
		{
			if(!g_bUsePrefixFile)
			{
				GetCmdArgString(g_sPrefix[iClient], sizeof(g_sPrefix[]));
				if(g_sPrefix[iClient][0] == '\0') strcopy(g_sPrefix[iClient], sizeof(g_sPrefix[]), "Префикс");
				SetClientCookie(iClient, g_hCookie[PREFIX], g_sPrefix[iClient]);
				PrintToChat(iClient, "\x04[Shop] \x01Вы установили себе префикс: \x04%s", g_sPrefix[iClient]);
			} else PrintToChat(iClient, "\x04[Shop] \x01Даная команда недоступна!");
		} else PrintToChat(iClient, "\x04[Shop] \x01Для доступа к этой команде купите префикс в \x04Shop\x01!");
	}
}

public Action:OnClientSayCommand(iClient, const String:command[], const String:sArgs[])
{
	if(iClient > 0 && !IsFakeClient(iClient) && IsClientInGame(iClient))
	{
		if(BaseComm_IsClientGagged(iClient)) return Plugin_Handled;
		if(g_bUsed[iClient][NAME_COLOR] || g_bUsed[iClient][TEXT_COLOR] || g_bUsed[iClient][PREFIX_COLOR])
		{
			if(sArgs[1] == '@' || sArgs[1] == '/') return Plugin_Continue;

			decl String:sText[192];
			strcopy(sText, sizeof(sText), sArgs);
			TrimString(sText);
			StripQuotes(sText);
			
			new iTeam = GetClientTeam(iClient);
			decl String:sNameColor[80], String:sTextColor[210], String:sPrefix[120];
				
			FormatEx(sNameColor, sizeof(sNameColor), "%s%N", (g_bUsed[iClient][NAME_COLOR]) ? g_sColors[iClient][NAME_COLOR]:"\x03", iClient);
			FormatEx(sTextColor, sizeof(sTextColor), "\x01: %s%s", (g_bUsed[iClient][TEXT_COLOR]) ? g_sColors[iClient][TEXT_COLOR]:"", sText);
				
			if(g_bUsed[iClient][PREFIX_COLOR]) FormatEx(sPrefix, sizeof(sPrefix), "%s%s ", g_sColors[iClient][PREFIX_COLOR], g_sPrefix[iClient]);
			else sPrefix[0] = '\0';

			if(StrEqual(command, "say"))
			{
				FormatEx(sText, sizeof(sText), "\x01%s%s%s%s", (iTeam < 2) ? "*НАБЛЮДАТЕЛЬ* ":((IsPlayerAlive(iClient)) ? "":"*УБИТ* "), sPrefix, sNameColor, sTextColor);
				new Handle:h = StartMessageAll("SayText2");
				if (h != INVALID_HANDLE) 
				{ 
					BfWriteByte(h, iClient); 
					BfWriteByte(h, true);
					BfWriteString(h, sText); 
					EndMessage();
				}
			} else if(StrEqual(command, "say_team"))
			{
				FormatEx(sText, sizeof(sText), "\x01%s %s%s%s%s", (iTeam < 2) ? "(Наблюдатель)":((iTeam == 2) ? "(Террорист)":"(Спецназовец)"), (iTeam < 2) ? "":((IsPlayerAlive(iClient)) ? "":"*УБИТ* "), sPrefix, sNameColor, sTextColor);
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam) 
					{
						new Handle:h = StartMessageOne("SayText2", i);
						if (h != INVALID_HANDLE) 
						{ 
							BfWriteByte(h, iClient); 
							BfWriteByte(h, true);
							BfWriteString(h, sText); 
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

stock CheckCloseHandle(&Handle:handle)
{
	if (handle != INVALID_HANDLE)
	{
		CloseHandle(handle);
		handle = INVALID_HANDLE;
	}
}