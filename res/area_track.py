import os
import json

os.chdir(os.path.dirname(__file__))


def area_track_lua_code(area, vertexes):
    if len(area["vertexes"]) == 0:
        return ""
    listVertex = "{" + ",".join(
        ["{" + f"x={vertexes[id]['x']},z={vertexes[id]['z']}" + "}" for id in area["vertexes"]]) + "}"
    # listVertex = "{" + ",".join([f"V[{id}]" for id in area["vertexes"]]) + "}"
    listRelated = "AreasGetter({" + ",".join(
        [str(id).replace('Area_', '') for id in area["related"]]) + "})"
    return f"Area.overWrite(AreaGetter({str(area['name']).replace('Area_','')}),\"{str(area['name']).replace('Area_','')}\",{listVertex},{area['left_vertex_inner_id']+1},{listRelated},{area['callback'] or 'function()end'})"


def track_lua_code(track):
    arealist = "AreasGetter({" + ",".join(
        [id['name'].replace('Area_', '') for id in track["areas"]]) + "})"
    return f"CreateTrack(\"{track['name']}\",{arealist})"

# {"name":"NHB4LT",
# "areas":[{"name":"Area_38","trackFlag":"none"},{"name":"Area_37","trackFlag":"none"},{"name":"Area_39","trackFlag":"none"}]
# }

# @class Area
# @field name string
# @field vertexs Vector2d[] @反時計回りにエリアの頂点を定義
# @field leftVertexId number
# @field axles Axle[] @左から順に車軸情報
# @field nodeToArea Area[] @隣り合うエリア・ポリゴンへの参照


with (open("area_track.json", "rb") as json_f, open("area_track.lua", "w", encoding="utf-8") as lua_f):
    data = json.load(json_f)
    v = data["vertexes"]

    vv = {}
    for vx in v:
        vv[vx['name']] = vx

    for a in data["areas"]:
        print(area_track_lua_code(a, vv), file=lua_f)

    for a in data["tracks"]:
        print(track_lua_code(a), file=lua_f)
