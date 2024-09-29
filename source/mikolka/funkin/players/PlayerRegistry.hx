package mikolka.funkin.players;

import haxe.Json;
import mikolka.funkin.players.PlayerData;
import mikolka.compatibility.FunkinPath;

using mikolka.funkin.custom.FunkinTools;
using StringTools;
//TODO softcode this soon
class PlayerRegistry {
    public static var instance:PlayerRegistry = new PlayerRegistry();
    public function new() {
        
    }
    // Based on a character ID from a stage obtain it's playable character ID
    public function getCharacterOwnerId(charId:String) {
        var binds = new Map<String,String>();
        binds.set("pico-playable","pico");
        return binds.get(charId) ?? "bf";
    }
    public function fetchEntry(playableCharId:String):PlayableCharacter {
        var char_path = FunkinPath.getPath('registry/playableChars/$playableCharId.json');
        var text = File.getContent(char_path);

        var player_blob:Dynamic = Json.parse(text);// new PlayerData();
        var player_data = new PlayerData().mergeWithJson(player_blob,["freeplayDJ"]);
        var dj = new PlayerFreeplayDJData().mergeWithJson(player_blob.freeplayDJ);
        player_data.freeplayDJ = dj;
        return new PlayableCharacter(player_data);
    }

    public function isCharacterOwned(id:String):Bool {
        return true;
    }
    // return ALL characters avaliable (from current mod)
    public function listEntryIds():Array<String> {
        var char_path = FunkinPath.getPath('registry/playableChars/');
        var basedCharFiles = FileSystem.readDirectory(char_path);
        if(char_path == 'mods/registry/playableChars'){
            var nativeChars = FileSystem.readDirectory(FunkinPath.getPath('registry/playableChars/',true));
            basedCharFiles = basedCharFiles.concat(nativeChars);
        }
        return basedCharFiles.filter(s -> s.endsWith(".json")).map(s -> s.substr(0,s.length-5));
    }
}