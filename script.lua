ADDON_NAME = "N-TRACS Soya Express Wayside Signals"
ADDON_SHORT_NAME = "SoyaExpress WS"
ADDON_VERSION = "v1.0.2"
CTC_VERSION = "SoyaWS-2"

-- 1. Load N-TRACS Core
require("src.n_tracs_core")

-- 2. Load bridge
require("src.n_tracs_soyabridge")

-- 3. Load settings
require("res.utils")
require("res.area_track")
require("res.signal")
require("res.signal_alias")
require("res.switch")
require("res.crossing")
require("res.ctc")

DEFAULT_AREA = AreaGetter(2)
Lever.setInput(LEVERS["WAK1R"], true, false)
Lever.setInput(LEVERS["WAK4L"], true, false)
Lever.setInput(LEVERS["SGN1R"], true, false)
Lever.setInput(LEVERS["SGN2R"], true, false)
Lever.setInput(LEVERS["SGN5L"], true, false)

-- Stormworksを騙す。関数の後にコンマを入れないと認識してくれないようである。
fake_property =
	[[
g_savedata = {
	recommendedSettings = property.checkbox("Start with no wind and damage", true),
	cheatBattery = property.checkbox("Enable cheat_battery feature", true),
}
--]]

_ENV["g_savedata"] = {
	recommendedSettings = property.checkbox("Start with no wind and damage", true),
	cheatBattery = property.checkbox("Enable cheat_battery feature", true)
}

function onCreate(is_world_create)
	if is_world_create and _ENV["g_savedata"].recommendedSettings then
		server.setGameSetting("vehicle_damage", false)
		server.setGameSetting("player_damage", false)
		server.setGameSetting("npc_damage", false)
		local starttile = server.getStartTile()
		local weather = server.getWeather(matrix.translation(starttile.x, starttile.y, starttile.z))
		server.setGameSetting("override_weather", true)
		server.setWeather(weather.fog, weather.rain, 0)
	end
end

---@type PointSetter[]
POINTLIST = {}
for _, data in pairs(BRIDGE_SWITCH) do
	for key, _ in pairs(data.pointAndRoute) do
		POINTLIST[key] = SwitchBridge.getPointSetter(data, key)
	end
end

---[Stormworks] onTick function.
-- 1 Tickごとに呼び出されます.
---@diagnostic disable-next-line: lowercase-global
function onTick()
	TickCounter = (TickCounter or 0) + 1

	-- 毎Tick実行しないとsignal_batを3に充電できない
	if _ENV["g_savedata"].cheatBattery then
		for vehicle_id, _ in pairs(VehicleTable) do
			server.setVehicleBattery(vehicle_id, "signal_bat", 3)
			server.setVehicleBattery(vehicle_id, "cheat_battery", 1)
		end
	else
		for vehicle_id, _ in pairs(VehicleTable) do
			server.setVehicleBattery(vehicle_id, "signal_bat", 3)
		end
	end

	Phase = ((Phase or 0) + 1) % 6
	if Phase == 1 then
		-- データの初期化及びビークルデータの取得フェーズ
		for _, area in pairs(AREAS) do
			Area.initializeForProcess(area)
		end

		for vehicle_id, data in pairs(VehicleTable) do
			if data.axles then
				for _, axle in ipairs(data.axles) do
					Axle.initializeForProcess(axle)
				end
			end

			if data.bridges then
				for _, setter in ipairs(data.bridges.points) do
					local dial, ss = server.getVehicleDial(vehicle_id, setter.pointName .. "K")
					if ss then
						setter.set(dial.value)
					--else
					--ARCを実装したら 0 にするようにする。
					--setter.set(0)
					end
				end
			end
		end

		-- CTCデータ取得
		if CTC_AVAILABLE and CTC then
			GetCtcState()
		end
	elseif Phase == 2 then
		-- 取得データをCoreに処理させるのに適した状態に変換するフェーズ
		for _, data in pairs(VehicleTable) do
			if data.axles then
				for _, axle in ipairs(data.axles) do
					Axle.search(axle)
				end
			end
		end

		-- CTC取得データの変換
		if CTC_AVAILABLE and CTC_ACTIVE then
			SetCtcState()
		end
	elseif Phase == 3 then
		for _, data in pairs(BRIDGE_TRACK) do
			Track.beforeProcess(TRACKS[data.itemName], TrackBridge.isInAxle(data))
		end

		-- 方向てこなどの処理が必要な場合はここまでの段階でBRIDGE_SWITCHに入れておく
		for _, data in pairs(BRIDGE_SWITCH) do
			Switch.beforeProcess(SWITCHES[data.itemName], SwitchBridge.getState(data))
		end

		for _, data in pairs(LEVERS) do
			SignalBase.beforeProcess(data)
		end
	elseif Phase == 4 then
		-- Coreで処理するフェーズ
		for _, track in pairs(TRACKS) do
			Track.process(track, 6)
		end

		for _, lever in pairs(LEVERS) do
			SignalBase.process(lever, 6)
		end

		-- 特殊処理
		BridgeCrossing(6)
	elseif Phase == 5 then
		-- Coreで処理したデータを配信用に加工するフェーズ
		for _, area in pairs(AREAS) do
			area.cbdata = area.updateCallback and area.updateCallback(area, 6)
		end

		-- CTCデータ生成
		if CTC_AVAILABLE and CTC then
			MakeCtcData()
		end
	elseif Phase == 0 then
		-- 全ての情報を配信するフェーズ
		SendingSign = (SendingSign or -1) * -1
		for vehicle_id, data in pairs(VehicleTable) do
			if data.axles then
				for _, axle in ipairs(data.axles) do
					Axle.send(axle)
				end
			end

			if data.bridges then
				SendBridge(vehicle_id, data.bridges)
			end
		end

		if CTC_AVAILABLE and CTC then
			SendCtcData(SendingSign)
		end

		while #DELAY_ANNOUNE > 0 do
			local calls = table.remove(DELAY_ANNOUNE, 1)
			if type(calls) == "function" then
				calls()
			end
		end
	end
end
