package be.haxer.hxswfml;
import format.swf.Data;
import format.abc.Data;
/**
 * ...
 * @author Jan J. Flanders
 */
class AbcWriter
{
	public var log:Bool;
	public var strict:Bool;
	public var name:String;
	var ctx:format.abc.Context;
	var jumps:Hash < Void->Void > ;
	var switches:Hash<Void->Void> ;
	var labels:Hash<Null<JumpStyle>->Int>;
	var imports:Hash<String>;
	var functionClosures:Hash <Index<MethodType >> ;
	var inits:Hash<Index<MethodType>> ;
	var classDefs:Hash<Index<ClassDef>> ;
	var abcFile:ABCData;
	var swfTags:Array<SWFTag>;
	var className:String;
	var curClassName:String;
	var curClass:ClassDef;
	var classNames:Array<String>;
	var swcClasses:Array < Array < String >> ;
	var functionClosureName:String;
	var lastBytepos:Int;
	var maxStack:Int;
	var maxScopeStack:Int;
	var currentStack:Int;
	var currentScopeStack:Int;
	public function new ()
	{
	}
	public function write(xml:String):haxe.io.Bytes
	{
		swfTags = new Array();
		swcClasses = new Array();
		lastBytepos = 0;
		var abcfiles:Xml = Xml.parse(xml).firstElement();
		if(abcfiles.nodeName.toLowerCase()=="abcfile")
		{
			swfTags.push(xml2abc(abcfiles));
		}
		else
		{
			for (abcfile in abcfiles.elements())
			{
				swfTags.push(xml2abc(abcfile));
			}
		}
		return Type.enumParameters(swfTags[0])[0];
	}
	public function getTags():Array<SWFTag>
	{
		return swfTags;
	}
	public function getABC():haxe.io.Bytes
	{
		if(swfTags.length>1)
			return Type.enumParameters(swfTags[0])[0];//todo
		else
			return Type.enumParameters(swfTags[0])[0];
	}
	public function getSWF(className:String=null, version:Int=10, compressed:Bool=true, width:Int=800, height:Int=600, fps:Int=30, nframes:Int=1):haxe.io.Bytes
	{
		var swfFile = 
		{
			header: {version:version, compressed:compressed, width:width, height:height, fps:fps, nframes:nframes},
			tags:[]
		};
		swfFile.tags.push(TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}));
		swfFile.tags.push(TScriptLimits(1000, 60));
		for(t in swfTags)
			swfFile.tags.push(t);
		swfFile.tags.push(TSymbolClass([{cid:0, className:className!=null?className:classNames.pop()}]));
		swfFile.tags.push(TShowFrame);
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new format.swf.Writer(swfOutput);
		writer.write(swfFile);
		return swfOutput.getBytes();
	}
	public function getSWC(?className):haxe.io.Bytes
	{
		var swfFile = 
		{
			header: {version:10, compressed:true, width:500, height:400, fps:30, nframes:1},
			tags:[]
		};
		swfFile.tags.push(TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}));
		for(t in swfTags)
			swfFile.tags.push(t);
		swfFile.tags.push(TSymbolClass([ { cid:0, className:className != null?className:classNames.pop() } ]));
		swfFile.tags.push(TShowFrame);
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new format.swf.Writer(swfOutput);
		writer.write(swfFile);
		var library = swfOutput.getBytes();
		var swcWriter = new SwcWriter();

		swcWriter.write(swcClasses, library);
		var swc = swcWriter.getSWC();
		return swc;
	}
	public function abc2swf(data:haxe.io.Bytes)
	{
		var abcReader = new format.abc.Reader(new haxe.io.BytesInput(data));
		var abcFile = abcReader.read();
		var inits = abcFile.inits;
		var init = inits.pop();
		var fields = init.fields;
		var className="";
		for(f in fields)
		{
			switch(f.kind)
			{
				case FClass(c):
					var iName = abcFile.classes[Type.enumParameters(c)[0]].name;
					var name = abcFile.get(abcFile.names, iName);
					switch (name)
					{
						case NName(id, ns):
							classNames = [abcFile.get(abcFile.strings, id)];
						default:
					}
				default:
			}
		}
		swfTags=[TActionScript3(data, { id : 1, label : className} )];
	}
	private function xml2abc(xml):SWFTag
	{	
		var ctx_xml:Xml = xml;
		ctx = new format.abc.Context();
		jumps = new Hash();
		labels = new Hash();
		switches = new Hash();
		curClassName="";
		var statics:Array<OpCode>=new Array();
		imports = new Hash();
		functionClosures = new Hash();
		inits= new Hash();
		classDefs = new Hash();
		classNames = new Array();
		//swcClasses = new Array();
		var ctx = ctx;
		
		//FUNCTIONS
		for(_classNode in ctx_xml.elements())
		{
			switch(_classNode.nodeName)
			{
				case 'function':
					createFunction(_classNode, 'function');
				default :
			}
		}
		
		//VARs & METHODs
		for(_classNode in ctx_xml.elements())
		{
			switch(_classNode.nodeName.toLowerCase())
			{
				default : 
					throw ('<'+_classNode.nodeName + '> Must be <function>, <init>, <import> or <class [<var>], [<function>]>.');
					
				case 'import':
					var n = _classNode.get('name');
					var cn = n.split('.').pop();
					imports.set(cn, n);
					
				case 'function', 'init':

				case 'class', 'interface':
					className = _classNode.get('name');
					classNames.push(className);
					var cl = ctx.beginClass(className, _classNode.get('interface') == 'true');
					curClass = cl;
					classDefs.set(className, ctx.getClass(cl));
					curClassName = className.split(".").pop();
					if (_classNode.get('implements') != null)
					{
						cl.interfaces = [];
						for (i in _classNode.get('implements').split(','))
							cl.interfaces.push(ctx.type(getImport(i)));
					}
					cl.isFinal = _classNode.get('final') == 'true';
					cl.isInterface = _classNode.get('interface') == 'true';
					cl.isSealed = _classNode.get('sealed') == 'true';
					//cl.Namespace = NamespaceType(_classNode.get('ns'));//ctx.Namespace(NProtected(ctx.string(curClassName)));
					var _extends = _classNode.get('extends');
					ctx.isExtending =false;
					if (_extends != null)
					{
						if (_extends != 'Object') 
							ctx.isExtending = true;
						cl.superclass = ctx.type(getImport(_extends));
						ctx.addClassSuper(getImport(_extends));
					}
					swcClasses.push([className, _extends==null?"Object":_extends]);
					for(member in _classNode.elements())
					{
						switch(member.nodeName)
						{
							case 'var':
								var name:String = member.get('name');
								var type:String = member.get('type');
								if (type == null || type == "")
									type = '*';
								var isStatic:Bool = member.get('static') == 'true';
								var value:String = member.get('value');
								var _const:Bool = member.get('const') == 'true';
								var ns = NamespaceType(member.get('ns'));
								var slot = Std.parseInt(member.get('slot'));
								var _value = (value==null)?null: switch (type)
								{
									case 'String': VString(ctx.string(value));
									case 'int': VInt(ctx.int(parseInt32(value)));
									case 'uint': VUInt(ctx.uint(parseInt32(value)));
									case 'Number':  VFloat(ctx.float(Std.parseFloat(value)));
									case 'Boolean': VBool(value == 'true');
									default : null; //throw('You must provide a datatype for: ' +  name +  ' if you provide a value here.(Supported types for predefined values are String, int, uint, Number, Boolean)');
								};
								ctx.defineField(name, ctx.type(getImport(type)), isStatic, _value, _const, ns, slot);

							case 'function':
								createFunction(member, 'method', cl.isInterface);

							default : 
								throw (member.nodeName + ' Must be <function/> or <var/>.');
						}
					}

					//check if custom init function exists.
					for(_classNode in ctx_xml.elements())
					{
						switch(_classNode.nodeName)
						{
							case 'init':
								if (_classNode.get('name') == className)
									createFunction(_classNode, 'init');
							default :
						}
					}
					if (inits.exists(className))
					{
						ctx.getData().inits[ctx.getData().inits.length - 1].method = inits.get(className);
						ctx.endClass(false);
					}
					else
					{
						ctx.endClass();
					}
			}
		}
		var abcOutput = new haxe.io.BytesOutput();
		format.abc.Writer.write(abcOutput, ctx.getData());
		return TActionScript3(abcOutput.getBytes(), { id : 1, label : className } );
	}
	private function createFunction(node:Xml, functionType:String, ?isInterface:Bool=false)
	{
		maxStack= 0;
		currentStack = 0;
		maxScopeStack = 0;
		currentScopeStack = 0;
		var args:Array<IName> = new Array();
		var _args = node.get('args');
		if (_args == null || _args == "")
			args = [];
		else
			for(i in _args.split(','))
				args.push(ctx.type(getImport(i)));
		var _return =  (node.get('return')==""|| node.get('return')==null)? ctx.type('*') : ctx.type(getImport(node.get('return')));
		var _defaultParameters:Null<Array<Value>> = null;
		var defaultParameters = node.get('defaultParameters');
		if (defaultParameters != null)
		{
			var values = defaultParameters.split(',');
			_defaultParameters = new Array();
			for (v in 0...values.length)
			{
				if (values[v] == "")
					_defaultParameters.push(null);//_defaultParameters.push(null);
				else
				{
					var pair = values[v].split(":");
					var v = pair[0];
					var t = pair[1];
					var _value = switch (t)
					{
						case 'String': VString(ctx.string(v));
						case 'int': VInt(ctx.int(parseInt32(v)));
						case 'uint': VUInt(ctx.uint(parseInt32(v)));
						case 'Number':  VFloat(ctx.float(Std.parseFloat(v)));
						case 'Boolean': VBool(v == 'true');
						default : null;
					};
					_defaultParameters.push(_value);//_defaultParameters.push(null);
				}
			}
		}
		var extra = 
		{
			native : node.get('native')=="true",
			variableArgs : node.get('variableArgs')=="true",
			argumentsDefined : node.get('argumentsDefined')=="true",
			usesDXNS : node.get('usesDXNS')=="true",
			newBlock : node.get('newBlock')=="true",
			unused : node.get('unused')=="true",
			debugName : ctx.string(node.get('debugName')==null?"":node.get('debugName')),
			defaultParameters : _defaultParameters,
			paramNames : null//Null<Array<Null<Index<String>>>>;
		}
		var ns = NamespaceType(node.get('ns'));
		var f = null;
		if (functionType == 'function')
		{
			ctx.beginFunction(args, _return, extra);
			f = ctx.curFunction.f;
			var name = node.get('f');
			functionClosureName = name;
			functionClosures.set(name, f.type);
		}
		else if (functionType == 'method')
		{
			var _static = node.get('static')=="true";
			var _override = node.get('override')=="true";
			var _final = node.get('final') == "true";
			var _later = node.get('later') == "true";

			var kind:MethodKind = switch(node.get('kind')) 
			{ 
				case 'normal':KNormal; 
				case 'set', 'setter' : KSetter; 
				case 'get', 'getter' : KGetter; 
				default: KNormal; 
			};
			if (node.get('name') == className )
			{
				if (_static == true)
				{
					ctx.beginFunction(args, _return, extra);
					f = ctx.curFunction.f;
					curClass.statics = f.type;
				}
				else
				{
					if (isInterface)
					{
						f = ctx.beginInterfaceMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  true, kind, extra, ns);
						curClass.constructor = f.type;
						return f;
					}
					else
					{
						f = ctx.beginMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  true, kind, extra, ns);
						curClass.constructor = f.type;
					}
				}
			}
			else
			{
				if (isInterface)
				{
					var f = ctx.beginInterfaceMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  _later, kind, extra, ns);
					return f;
				}
				else
				f = ctx.beginMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  _later, kind, extra, ns);
			}
			
		}
		else if (functionType == 'init')
		{
			ctx.beginFunction(args, _return,extra);
			f = ctx.curFunction.f;
			var name = getImport(node.get('name'));
			inits.set(name, f.type);
		}
		
		if (node.get('locals') != null)
		{
			var locals = parseLocals(node.get('locals'));
			if (locals.length != 0) 
				f.locals = locals;
		}

		writeCodeBlock(node, f);
		
		if (node.get('maxStack') != null)
			f.maxStack = Std.parseInt(node.get('maxStack'));
		else
			f.maxStack = maxStack + f.trys.length;
									
		if (node.get('maxScope') != null)
			f.maxScope = Std.parseInt(node.get('maxScope'));
		else
			f.maxScope = maxScopeStack;
									
		if (currentStack > 0) 
			nonEmptyStack(node.get('name'));
		return f;
	}
	private function writeCodeBlock(member:Xml, f)/*:Bool*/
	{
		if (log)
		{
			if(className==null)
				logStack("------------------------------------------------\nfunction= " + functionClosureName +"\ncurrentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack + "\n\n");
			else
				logStack("------------------------------------------------\ncurrent class= " + className + ', method= ' + member.get('name') + "\ncurrentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack + "\n\n");
		}
		lastBytepos = ctx.bytepos.n;
		for (o in member.elements())
		{
			var op:Null<OpCode> = null;
			op = switch(o.nodeName)
			{
				case	"OBreakPoint", "ONop", "OThrow", "ODxNsLate", "OPushWith", "OPopScope", "OForIn", "OHasNext", "ONull", "OUndefined", "OForEach", "OTrue", "OFalse", 
						"ONaN", "OPop", "ODup", "OSwap", "OScope", "ONewBlock", "ORetVoid", "ORet", "OToString", "OGetGlobalScope", "OInstanceOf", "OToXml", "OToXmlAttr", "OToInt",
						"OToUInt", "OToNumber", "OToBool", "OToObject", "OCheckIsXml", "OAsAny", "OAsString", "OAsObject", "OTypeof", "OThis", "OSetThis", "OTimestamp":
						Type.createEnum(OpCode, o.nodeName);
	
				case	"ODxNs", "ODebugFile" :
						Type.createEnum(OpCode, o.nodeName, [ctx.string(o.get('v'))]);
						
				case	"OString":
						Type.createEnum(OpCode, o.nodeName, [ctx.string(urlDecode(o.get('v')))]);
												
				case	"OIntRef":
						Type.createEnum(OpCode, o.nodeName, [ctx.int(parseInt32(o.get('v')))]);
						
				case "OUIntRef":
						Type.createEnum(OpCode, o.nodeName, [ctx.uint(parseInt32(o.get('v')))]);
												
				case	"OFloat":
						Type.createEnum(OpCode, o.nodeName, [ctx.float(Std.parseFloat(o.get('v')))]);
												
				case	"ONamespace":
						Type.createEnum(OpCode, o.nodeName, [ctx.type(o.get('v'))]);
												
				case	"OClassDef":
						if (!classDefs.exists(o.get('v')))
							throw o.get('v') + ' must be created as class before referencing it here.';
						else
							Type.createEnum(OpCode, o.nodeName, [classDefs.get(o.get('v'))]);
	
				case	"OFunction":
						if (!functionClosures.exists(o.get('v')))
							throw o.get('v') + ' must be created as function (closure) before referencing it here.';
						else
							Type.createEnum(OpCode, o.nodeName, [functionClosures.get(o.get('v'))]);
											
				case	"OGetSuper", "OSetSuper", "OGetDescendants", "OFindPropStrict", "OFindProp", "OFindDefinition", "OGetLex", "OSetProp", "OGetProp", "OInitProp", 
						"ODeleteProp", "OCast", "OAsType", "OIsType":
						var v = o.get('v');
						if (v == '#arrayProp')
							Type.createEnum(OpCode, o.nodeName, [ctx.arrayProp]);
						else
							Type.createEnum(OpCode, o.nodeName, [ctx.type(getImport(v))]);

				case	"OCallSuper", "OCallProperty", "OConstructProperty", "OCallPropLex", "OCallSuperVoid", "OCallPropVoid":
						var p = o.get('v');
						var nargs = Std.parseInt(o.get('nargs'));
						if (p == '#arrayProp')
							Type.createEnum(OpCode, o.nodeName, [ctx.arrayProp,nargs]);
						else
							Type.createEnum(OpCode, o.nodeName, [ctx.type(getImport(p)),nargs]);
												
				case	"ORegKill", "OReg", "OIncrReg", "ODecrReg", "OIncrIReg", "ODecrIReg", "OSmallInt", "OInt", "OGetScope", "ODebugLine", "OBreakPointLine", "OUnknown", 
						"OCallStack", "OConstruct", "OConstructSuper", "OApplyType", "OObject", "OArray", "OGetSlot", "OSetSlot", "OGetGlobalSlot", "OSetGlobalSlot":
						var v = Std.parseInt(o.get('v'));
						Type.createEnum(OpCode, o.nodeName, [v]);
						
				case	"OCatch":
						var start = Std.parseInt(o.get('start'));
						var end =  Std.parseInt(o.get('end'));
						var handle =  Std.parseInt(o.get('handle'));
						var type =  ctx.type(getImport(o.get('type')));
						var variable = ctx.type(getImport(o.get('variable')));
						f.trys.push( { start:start, end:end, handle:handle,  type:type, variable:variable} );
						Type.createEnum(OpCode, o.nodeName, [f.trys.length-1]);
											
				case	"OSetReg":
						ctx.allocRegister();
						var v = Std.parseInt(o.get('v'));
						Type.createEnum(OpCode, o.nodeName, [v]);
											
				case	"OpAs", "OpNeg", "OpIncr", "OpDecr", "OpNot", "OpBitNot", "OpAdd", "OpSub", "OpMul", "OpDiv", "OpMod", "OpShl", "OpShr", "OpUShr", "OpAnd", "OpOr", 
						"OpXor", "OpEq", "OpPhysEq", "OpLt", "OpLte", "OpGt", "OpGte", "OpIs", "OpIn", "OpIIncr", "OpIDecr", "OpINeg", "OpIAdd", "OpISub", "OpIMul", 
						"OpMemGet8", "OpMemGet16", "OpMemGet32", "OpMemGetFloat", "OpMemGetDouble", "OpMemSet8", "OpMemSet16", "OpMemSet32", "OpMemSetFloat", 
						"OpMemSetDouble", "OpSign1", "OpSign8", "OpSign16":
						Type.createEnum(OpCode, 'OOp', [Type.createEnum(Operation, o.nodeName)]);
												
				case 	"OOp" :
						Type.createEnum(OpCode, 'OOp', [Type.createEnum(Operation, o.get('v'))]);
												
				case	"OCallStatic":
						var meth:Index<MethodType> = Idx(Std.parseInt(o.get('v')));// ctx.type(o.get('meth'));
						var nargs = Std.parseInt(o.get('nargs'));
						Type.createEnum(OpCode, o.nodeName, [meth, nargs]);//??
											
				case	"OCallMethod":
						Type.createEnum(OpCode, o.nodeName, [Std.parseInt(o.get('v')), Std.parseInt(o.get('nargs'))]);
												
				
							
				case	"JNotLt", "JNotLte", "JNotGt", "JNotGte", "JAlways", "JTrue", "JFalse", "JEq", "JNeq", "JLt", "JLte", "JGt", "JGte", "JPhysEq", "JPhysNeq":
						var jump = Type.createEnum(JumpStyle, o.nodeName);
						var jumpName = o.get('jump');
						var labelName = o.get('label');
						var out:Null<OpCode>=null;
						if (jumpName != null)
							jumps.set(jumpName, ctx.jump(jump));
						else if (labelName != null)
							labels.get(labelName)(jump);//labels.get(labelName)(jump, false);
						updateStacks(OJump(jump, 0));
						out;
						
				case	"OLabel":
						if (o.get('name') != null)
						{
							if (log)
							{
								logStack('OLabel name='+o.get('name'));
								updateStacks(OLabel);
							}
							labels.set(o.get('name'), ctx.backwardJump());
							null;
						}
						else
						{
							Type.createEnum(OpCode, o.nodeName, []);
						}
						
				case	"OJump":
						var jumpName = o.get('name');
						var out:Null<OpCode>=null;
						if (jumpName != null)
						{
							var jumpFunc = jumps.get(jumpName);
							jumpFunc();
							if (log) 
								logStack('OJump name=' + jumpName);
						}
						else
						{
							var j = Type.createEnum(JumpStyle, o.get('jump'), []);
							var offset = Std.parseInt(o.get('offset'));
							out = Type.createEnum(OpCode, o.nodeName, [j, offset]);
						}
						out; 
						
				case	"OSwitch":
						var def = Std.parseInt(o.get('default'));
						var arr = o.get('deltas').split('[').join('').split(']').join('').split(' ').join('').split(',');
						var deltas:Array<Int> = new Array();
						for ( i in arr)
							deltas.push(Std.parseInt(i));
						Type.createEnum(OpCode, o.nodeName, [def, deltas]);
						
				case	"OSwitch2":
						var def = o.get('default');
						var _def = 0;
						if(StringTools.startsWith(def,'label'))
							_def = labels.get(def)(null);//_def = labels.get(def)(JAlways, true);
						else
							switches.set(def, ctx.switchDefault());
						var arr = o.get('deltas').split('[').join('').split(']').join('').split(' ').join('').split(',');
						var offsets = [];
						for ( i in 0...arr.length)
						{
							if (StringTools.startsWith(arr[i],'label'))
							{
								offsets.push(labels.get(arr[i])(null));//offsets.push(labels.get(arr[i])(JAlways, true));
							}
							else
							{
								switches.set(arr[i], ctx.switchCase(i));
								offsets.push(0);
							}
						}
						Type.createEnum(OpCode, "OSwitch", [_def, offsets]);
				
				case	"OCase":
						var out:Null<OpCode>=null;
						var jumpName = o.get('name');
						var jumpFunc = switches.get(jumpName);
						jumpFunc();
						out;
												
				case	"ONext":
						Type.createEnum(OpCode, o.nodeName, [Std.parseInt(o.get('v1')), Std.parseInt(o.get('v2'))]);
												
				case	"ODebugReg":
						Type.createEnum(OpCode, o.nodeName, [ctx.string(o.get('name')), Std.parseInt(o.get('r')), Std.parseInt(o.get('line'))]);
												
				default	: 
						throw (o.nodeName + ' Unknown opcode.');
			}
			if (op != null)
			{
				updateStacks(op);
				ctx.op(op);
			}
		}
	}
	private function getImport(name:String):String
	{
		if (imports.exists(name))
			return imports.get(name);
		return name;
	}
	private function NamespaceType(ns:String)
	{
		return ctx._namespace(
			switch(ns)
				{
					case 'public': NPublic(ctx.string(""));
					case 'private': NPrivate(ctx.string("*"));
					case 'protected': NProtected(ctx.string(curClassName));
					case 'internal': NInternal(ctx.string(""));
					case 'Namespace': NNamespace(ctx.string(curClassName));
					case 'explicit': NExplicit(ctx.string(""));
					case 'staticProtected': NStaticProtected(ctx.string(curClassName));
					default : NPublic(ctx.string(""));
				});
	}
	private function parseLocals(locals:String):Null<Array<Field>> 
	{
		var locs:Array < String > = locals.split(',');
		var out:Array<Field> = new Array();
		var index:Int = 1;
		for (l in locs)
		{
			var props:Array < String > = l.split(':');
			out.push(
			{
				name : ctx.type(getImport(props[0])),
				slot : index,
				kind : parseFieldKind(l),
				metadatas : null
			}
			);
			index++;
		}
		return out;
	}
	private function parseFieldKind(fld:String):FieldKind
	{
		/*
		var props:Array < String > = fld.split(':');
		var name:String = props[0];
		var _name = ctx.type(name);
		var type:String = props[1];
		var _type = ctx.type(type);
		var value:String = props[2];
		var _value = 
		var const:String = props[3];
		for (p in props)
		{
			
		}*/
		return FVar();
	}
	static function parseInt32(s:String):haxe.Int32
	{
		var f=Std.parseFloat(s);
		if(f<-1073741824)
			return haxe.Int32.add(haxe.Int32.ofInt(-1073741824),haxe.Int32.ofInt(Std.int(f+1073741824)));
		if(f>1073741823)
			return haxe.Int32.add(haxe.Int32.ofInt(1073741823),haxe.Int32.ofInt(Std.int(f-1073741823)));
		return haxe.Int32.ofInt(Std.int(f));
	}
	private function nonEmptyStack(fname:String)
	{
		var msg = '!Possible error: Function ' + fname + ' did not end with empty stack. current stack: ' + currentStack;
		if (strict)
			throw(msg);
		if(log)
			logStack(msg);
	}
	private function stackError(op, type)
	{
		var o = Type.getEnum(op);
		var msg = type == 0? '!Possible error: stack underflow: ' + cast op : '!Possible error: stack overflow: ' + cast op;
		if (strict)
			throw (msg);
		if(log)
			logStack(msg);
	}
	private function scopeStackError(op, type)
	{
		var o = Type.getEnum(op);
		var msg = type == 0? '!Possible error: scopeStack underflow: ' + cast op : '!Possible error: scopeStack overflow: ' + cast op;
		if (strict)
			throw (msg);
		if(log)
			logStack(msg);
	}
	private function urlDecode(str:String):String
	{
		//return StringTools.urlDecode(str);
		 return str.split('&amp;').join('&').split('&quot;').join('"').split('&lt;').join('<').split('\\t').join('\t').split('\\r').join('\r').split('\\n').join('\n').split('\\u001b').join(String.fromCharCode(0x1b));
	}
	private function updateStacks(opc:OpCode) 
	{
		switch( opc ) 
		{
			case OBreakPoint: //0x01, ?, ?, ?

			case ONop: //0x02, nop, stack:0|0, scope:0|0

			case OThrow : //0x03, throw, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
					
			case OGetSuper(v): //0x04, getsuper, stack:-1 [-2]|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				++currentStack;
				
			case OSetSuper(v): //0x05, setsuper, stack:-(2[+2])|0, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				
			case ODxNs(i): //0x06, dxns, stack:0|0, scope:0|0

			case ODxNsLate: //0x07, dxnslate, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
					
			case ORegKill(r): //0x08, kill, stack:0|0, scope:0|0

			case OLabel: //0x09, label, stack:0|0, scope:0|0
			
			case OLabel2(name):
			//is no op

			case OJump(j,delta):
				switch( j ) 
				{
					case JAlways: //0x10, jump, stack:0|0, scope:0|0
					
					case JTrue, //0x11, iftrue, stack:-1|0, scope:0|0
						JFalse: //0x12, iffalse, stack:-1|0, scope:0|0
							if (--currentStack < 0) 
								stackError(opc, 0);
					case JNotLt, //0x0C, ifnlt, stack:-2|0, scope:0|0
						JNotLte, //0x0D, ifnle, stack:-2|0, scope:0|0
						JNotGt, //0x0E, ifngt,  stack:-2|0, scope:0|0
						JNotGte, //0x0F, ifnge,  stack:-2|0, scope:0|0
						JEq, //0x13, ifeq, stack:-2|0, scope:0|0
						JNeq, //0x14, ifne, stack:-2|0, scope:0|0
						JLt, //0x15, iflt, stack:-2|0, scope:0|0
						JLte, //0x16, ifle, stack:-2|0, scope:0|0
						JGt, //0x17, ifgt, stack:-2|0, scope:0|0
						JGte, //0x18, ifge, stack:-2|0, scope:0|0
						JPhysEq, //0x19, ifstricteq, stack:-2|0, scope:0|0
						JPhysNeq: //0x1A, ifstrictne, stack:-2|0, scope:0|0
							if ((currentStack-=2) < 0) 
								stackError(opc, 0);
				}
			case OJump2(j, landingName, offset):
			//is no op (internal use only)
			case OJump3( landingName ):
			//is no op (internal use only)
			
			case OSwitch(def,deltas): //0x1B, lookupswitch, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
			case OSwitch2(landingName,landingNames, offsets): 
				//is no op (internal use only)
			case OCase(landingName): 
				//is no op (internal use only)
					
			case OPushWith: //0x1C, pushwith, stack:-1|0, scope:0|+1
				if (--currentStack < 0) 
					stackError(opc, 0);
				maxScopeStack++;

			case OPopScope: //0x1D,popscope, stack:0|0, scope:-1|0
				if (--currentScopeStack < 0) 
					scopeStackError(opc, 0);

			case OForIn: //0x1E,nextname, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;
				
			case OHasNext: //0x1F,hasnext,stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;

			case ONull: //0x20, pushnull, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OUndefined: //0x21, pushundefined, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OForEach: //0x23, nextvalue, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OSmallInt(v): //0x24, pushbyte, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OInt(v): //0x25, pushshort, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OTrue ://0x26, pushtrue, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OFalse: //0x27, pushfalse, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case ONaN: //0x28, pushnan, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OPop: //0x29, pop,stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);

			case ODup: //0x2A, dup, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OSwap: //0x2B, swap, stack:-2|+2, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack+=2;

			case OString(v): //0x2C, pushstring, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OIntRef(v): //0x2D, pushint, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OUIntRef(v): //0x2E, pushuint, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OFloat(v): //0x2F, pushdouble, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OScope: //0x30, pushscope, stack:-1|0, scope:0|+1
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentScopeStack++;
				maxScopeStack++;

			case ONamespace(v): //0x31, pushNamespace, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case ONext(r1, r2): //0x32, hasnext2, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OFunction(f): //0x40, newfunction, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OCallStack(n): //0x41, call,stack:-(n+2)|+1, scope:0|0
				if ((currentStack-=(n+2)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OConstruct(n): //0x42, construct, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallMethod(s, n): //0x43, callmethod, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallStatic(m, n): //0x44, callstatic, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallSuper(p, n): //0x45, callsuper, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallProperty(p, n) ://0x46, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case ORetVoid: //0x47, returnvoid, stack:0|0, scope:0|0

			case ORet: //0x48, returnvalue, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);

			case OConstructSuper(n): //0x49, constructsuper, stack:-(n+1)|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);

			case OConstructProperty(p, n): //0x4A, constructprop, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallPropLex(p, n): //0x4C, callproplex, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCallSuperVoid(p, n): //0x4E, callsupervoid, stack:-(n+1[+2])|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);

			case OCallPropVoid(p, n):// 0x4F, callpropvoid, stack:-(n+1[+2])|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);

			case OApplyType(n): //0x53, int(n);?, ?
				if (--currentStack < 0) 
					stackError(opc, 0);
				
			case OObject(n): //0x55, newobject, stack:-(n*2)|+1, scope:0|0
				if ((currentStack-=(n*2)) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OArray(n): //0x56, newarray, stack:-n|+1, scope:0|0
				if ((currentStack-=n) < 0) 
					stackError(opc, 0);
				currentStack++;

			case ONewBlock: //0x57, newactivation, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OClassDef(c): //0x58, newclass, stack:-1|+1, scope:0|0 (scope stack must contain all the scopes of all base classes)
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OGetDescendants(i): //0x59, getdescendants, stack:-(1[+2])|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);

			case OCatch(c): //0x5A, newcatch, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OFindPropStrict(p): //0x5D, findpropstrict, stack:-[2]|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
					
			case OFindProp(p): //0x5E, findproperty, stack:-[2]|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
					
			case OFindDefinition(d): //0x5F,?,idx(d);?,?

			case OGetLex(p): //0x60, getlex, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OSetProp(p): //0x61, setproperty, stack:-(2[+2])|0, scope:0|0
				var popCount = 2;
				if (p == ctx.arrayProp)
					popCount = 3;
				if ((currentStack-=popCount) < 0) 
					stackError(opc, 0);

			case OReg(r): //0x62, getlocal, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				switch( r ) 
				{
					case 0: //0xD0, getlocal_0(this), stack:0|+1, scope:0|0
					case 1: //0xD1, getlocal_1, stack:0|+1, scope:0|0
					case 2: //0xD2, getlocal_2, stack:0|+1, scope:0|0
					case 3: //0xD3, getlocal_3, stack:0|+1, scope:0|0
					default: //0x62, getlocal_r, stack:0|+1, scope:0|0
				}
			case OSetReg(r): //0x63, setlocal, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				switch( r ) 
				{
					case 0: //0xD4, setlocal_0(this), stack:-1|0, scope:0|0
					case 1: //0xD5, setlocal_1, stack:-1|0, scope:0|0
					case 2: //0xD6, setlocal_2, stack:-1|0, scope:0|0
					case 3: //0xD7, setlocal_3, stack:-1|0, scope:0|0
					default: //0x63, setlocal_r, stack:-1|0, scope:0|0
				}
			case OGetGlobalScope: //0x64, getglobalscope, stack:0|+1, scope:0|0 (gets scopeStack[0]);
				if(++currentStack>maxStack)
					maxStack++;

			case OGetScope(n): //0x65, stack:0|+1, scope:0|0 (gets scopeStack[n]);
				if(++currentStack>maxStack)
					maxStack++;

			case OGetProp(p): //0x66, getproperty, stack:-(1[+2])|+1, scope:0|0
				if (p == ctx.arrayProp)
					if (--currentStack < 0) 
						stackError(opc, 0);
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				
			case OInitProp(p): //0x68, initproperty, stack:-(2[+2])|0, scope:0|0
				if ((currentStack -= 2) < 0)
				{
					stackError(opc, 0);
				}

			case ODeleteProp(p): //0x6A, deleteproperty, stack:-(1[+2])|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OGetSlot(s): //0x6C, getslot, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OSetSlot(s): //0x6D, setslot, stack:-2|0, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
					
			case OGetGlobalSlot(s): //0x6E, getglobalslot, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
			
			case OSetGlobalSlot(s): //0x6F, setglobalslot, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				
			case OToString: //0x70, convert_s, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToXml: //0x71, esc_xelem, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToXmlAttr: //0x72, esc_xattr, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToInt: //0x73, convert_i, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToUInt: //0x74, convert_u, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToNumber: //0x75, convert_d, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToBool: //0x76, convert_b, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OToObject: //0x77, convert_o, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCheckIsXml: //0x78, checkfilter, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OCast(t): //0x80, coerce, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OAsAny: //0x82, coerce_a, stack:-1|+1, scope:0|0
				if(currentStack==0){}
				else {
					if (--currentStack < 0) 
						stackError(opc, 0);
					}
				currentStack++;
				
				/*if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;*/

			case OAsString: //0x85, coerce_s, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OAsType(t): //0x86, astype, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OAsObject: //0x89,?,?,?

			case OIncrReg(r): //0x92, inclocal, stack:0|0, scope:0|0

			case ODecrReg(r): //0x94, declocal, stack:0|0, scope:0|0

			case OTypeof: //0x95, ypeof, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OInstanceOf: //0xB1, instanceof, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;

			case OIsType(t): //0xB2, istype, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;

			case OIncrIReg(r): //0xC2, inclocal_i, stack:0|0, scope:0|0

			case ODecrIReg(r): //0xC3, declocal_i, stack:0|0, scope:0|0

			case OThis: //0xD0, getlocal_<0>, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;

			case OSetThis: //0xD4, setlocal_<0>, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);

			case ODebugReg(name,r,line): //0xEF, debug, stack:0|0, scope:0|0

			case ODebugLine(line): //0xF0, debugline, stack:0|0, scope:0|0

			case ODebugFile(file): //0xF1, debugfile, stack:0|0, scope:0|0

			case OBreakPointLine(n): //0xF2,?,int(n);?,?
				
			case OTimestamp: //0xF3,?,?,?

			case OOp(op):
				switch( op ) 
				{
					case OpAs: //0x87, astypelate, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpNeg: //0x90, negate, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIncr: //0x91, increment, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpDecr: //0x93, decrement, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpNot: //0x96, not, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpBitNot: //0x97, bitnot, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpAdd: //0xA0, add, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpSub: //0xA1, subtract, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpMul: //0xA2, multiply, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpDiv: //0xA3, divide, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpMod: //0xA4, modulo, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpShl: //0xA5, lshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpShr: //0xA6, rshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpUShr: //0xA7, urshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpAnd: //0xA8, bitand, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpOr: //0xA9, bitor, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpXor: //0xAA, bitxor, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpEq: //0xAB, equals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpPhysEq: //0xAC, strictequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpLt: //0xAD, lessthan, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpLte: //0xAE, lessequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpGt: //0xAF, greaterequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpGte: //0xB0, ?, stack:-2+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIs: //0xB3, istypelate, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIn: //0xB4, in,stack:-2+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIIncr: //0xC0, increment_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIDecr: //0xC1, decrement_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpINeg: //0xC4, negate_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIAdd: //0xC5, add_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpISub: //0xC6, subtract_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpIMul: //0xC7, multiply_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						
					case OpMemGet8: //0x35, ?,??
					
					case OpMemGet16: //0x36, ?,??
					
					case OpMemGet32: //0x37, ?,??
					
					case OpMemGetFloat: //0x38,?,??
					
					case OpMemGetDouble: //0x39,?,??
					
					case OpMemSet8: //0x3A,?,??
					
					case OpMemSet16: //0x3B,?,??
					
					case OpMemSet32: //0x3C,?,??
					
					case OpMemSetFloat: //0x3D,?,??
					
					case OpMemSetDouble: //0x3E,?,??
					
					case OpSign1: //0x50,?,??
					
					case OpSign8: //0x51,?,??
					
					case OpSign16: //0x52,?,??
					
				}
			case OUnknown(byte)://b(byte);
		}
		if (log) 
		{
			logStack("bytepos:" + (ctx.bytepos.n-lastBytepos));
			logStack(cast opc);
			logStack("currentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack +"\n\n");
		}
	}
	private function logStack(msg)
	{
		trace(msg);
	}
	public static function createABC(className:String, baseClass:String):SWFTag
	{
		var ctx = new format.abc.Context();
		var c = ctx.beginClass(className, false);
		c.superclass = ctx.type(baseClass);
		switch(baseClass)
		{
			case 'flash.display.MovieClip' : 	
				ctx.addClassSuper("flash.events.EventDispatcher");
				ctx.addClassSuper("flash.display.DisplayObject");
				ctx.addClassSuper("flash.display.InteractiveObject");
				ctx.addClassSuper("flash.display.DisplayObjectContainer");
				ctx.addClassSuper("flash.display.Sprite");
				ctx.addClassSuper("flash.display.MovieClip");

			case 'flash.display.Sprite' : 
				ctx.addClassSuper("flash.events.EventDispatcher");
				ctx.addClassSuper("flash.display.DisplayObject");
				ctx.addClassSuper("flash.display.InteractiveObject");
				ctx.addClassSuper("flash.display.DisplayObjectContainer");
				ctx.addClassSuper("flash.display.Sprite");
				
			case 'flash.display.SimpleButton' : 
				ctx.addClassSuper("flash.events.EventDispatcher");
				ctx.addClassSuper("flash.display.DisplayObject");
				ctx.addClassSuper("flash.display.InteractiveObject");
				ctx.addClassSuper("flash.display.SimpleButton");
			
			case 'flash.display.Bitmap' : 
				ctx.addClassSuper("flash.events.EventDispatcher");
				ctx.addClassSuper("flash.display.DisplayObject");
				ctx.addClassSuper("flash.display.Bitmap");
			
			case 'flash.media.Sound' : 
				ctx.addClassSuper("flash.events.EventDispatcher");
				ctx.addClassSuper("flash.media.Sound");
				
			case 'flash.text.Font' : 
				ctx.addClassSuper("flash.text.Font");
			
			case 'flash.utils.ByteArray' : 
				ctx.addClassSuper("flash.utils.ByteArray");
		}
		var m = ctx.beginMethod(className, [], null, false, false, false, true);
		m.maxStack = 2;
		c.constructor = m.type;
		ctx.ops( [OThis, OConstructSuper(0), ORetVoid] );
		//ctx.finalize();
		ctx.endClass();
		var abcOutput = new haxe.io.BytesOutput();
		format.abc.Writer.write(abcOutput, ctx.getData());
		return TActionScript3(abcOutput.getBytes(), {id : 1, label : className});
	}
}