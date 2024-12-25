package codenameengine.scripting;

import haxe.io.Path;
import _hscript.Expr.ClassDecl;
import _hscript.Expr.ModuleDecl;
import _hscript.Expr.Error;
import _hscript.Parser;
import openfl.Assets;
import lime.utils.AssetType;
import _hscript.*;
import haxe.io.Path;

class HScript extends Script {
	public var interp:Interp;
	public var parser:Parser;
	public var expr:Expr;
	public var decls:Array<ModuleDecl> = null;
	public var code:String;
	public var folderlessPath:String;
	var __importedPaths:Array<String>;

	public static function initParser() {
		var parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		//parser.preprocesorValues = Script.getDefaultPreprocessors();
		return parser;
	}

	public override function onCreate(path:String) {
		super.onCreate(path);

		interp = new Interp();

		code = sys.io.File.getContent(path);
		parser = initParser();
		folderlessPath = Path.directory(path);
		__importedPaths = [path];

		interp.errorHandler = _errorHandler;
		interp.importFailedCallback = importFailedCallback;
		interp.staticVariables = Script.staticVariables;
		interp.allowStaticVariables = interp.allowPublicVariables = true;

		interp.variables.set("trace", Reflect.makeVarArgs((args) -> {
			var v:String = Std.string(args.shift());
			for (a in args) v += ", " + Std.string(a);
			this.trace(v);
		}));

		codenameengine.scripting.GlobalScript.call("onScriptCreated", [this, "hscript"]);

		if (code != null && code.trim() != "")
			loadFromString(code);
	}

	public override function loadFromString(code:String) {
		try {
			expr = parser.parseString(code, Path.withoutDirectory(fileName));
		} catch(e:Error) {
			trace('failed once');
			_errorHandler(e);
		} catch(e) {
			trace('failed twice');
			_errorHandler(new Error(ECustom(e.toString()), 0, 0, fileName, 0));
		}

		return this;
	}

	private function importFailedCallback(cl:Array<String>):Bool {
		var assetsPath = Paths.getPath('source/${cl.join("/")}');
		for(hxExt in ["hx", "hscript", "hsc", "hxs"]) {
			var p = '$assetsPath.$hxExt';
			if (__importedPaths.contains(p))
				return true; // no need to reimport again
			if (sys.FileSystem.exists(p)) {
				var code = sys.io.File.getContent(p);
				var expr:Expr = null;
				try {
					if (code != null && code.trim() != "")
						expr = parser.parseString(code, cl.join("/") + "." + hxExt);
				} catch(e:Error) {
					_errorHandler(e);
				} catch(e) {
					_errorHandler(new Error(ECustom(e.toString()), 0, 0, fileName, 0));
				}
				if (expr != null) {
					@:privateAccess
					interp.exprReturn(expr);
					__importedPaths.push(p);
				}
				return true;
			}
		}
		return false;
	}

	private function _errorHandler(error:Error) {

		var fn = '$fileName:${error.line}: ';
		var err = error.toString();
		if (err.startsWith(fn)) err = err.substr(fn.length);

		trace(fn);
		trace(err);

		#if HSCRIPT_ALLOWED
		if (PlayState.instance == flixel.FlxG.state)
			PlayState.instance.addTextToDebug('$fn, $err', flixel.util.FlxColor.RED, 16);
		else if (editors.content.EditorPlayState.instance == flixel.FlxG.state)
			editors.content.EditorPlayState.instance.addTextToDebug('$fn, $err', flixel.util.FlxColor.RED, 16);
		#end
	}

	public override function setParent(parent:Dynamic) {
		interp.scriptObject = parent;
	}

	public override function onLoad() {
		@:privateAccess
		interp.execute(parser.mk(EBlock([]), 0, 0));
		if (expr != null) {
			interp.execute(expr);
			call("new", []);
		}
	}

	public override function reload() {
		// save variables

		interp.allowStaticVariables = interp.allowPublicVariables = false;
		var savedVariables:Map<String, Dynamic> = [];
		for(k=>e in interp.variables) {
			if (!Reflect.isFunction(e)) {
				savedVariables[k] = e;
			}
		}
		var oldParent = interp.scriptObject;
		onCreate(path);

		for(k=>e in Script.getDefaultVariables(this))
			set(k, e);

		load();
		setParent(oldParent);

		for(k=>e in savedVariables)
			interp.variables.set(k, e);

		interp.allowStaticVariables = interp.allowPublicVariables = true;
	}

	private override function onCall(funcName:String, parameters:Array<Dynamic>):Dynamic {
		if (interp == null) return null;
        if (!interp.variables.exists(funcName)) return null;

		var func = interp.variables.get(funcName);
		if (func != null && Reflect.isFunction(func))
			return Reflect.callMethod(null, func, parameters);

		return null;
	}

	public override function get(val:String):Dynamic {
		return interp.variables.get(val);
	}

	public override function set(val:String, value:Dynamic) {
		interp.variables.set(val, value);
	}

	public override function trace(v:Dynamic) {
		var posInfo = interp.posInfos();
		trace('${fileName}:${posInfo.lineNumber}: ' + (Std.isOfType(v, String) ? v : Std.string(v)));
	}

	public override function setPublicMap(map:Map<String, Dynamic>) {
		this.interp.publicVariables = map;
	}
}