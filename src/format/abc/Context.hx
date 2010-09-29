/*
* format - haXe File Formats
* ABC and SWF support by Nicolas Cannasse
*
* Copyright (c) 2008, The haXe Project Contributors
* All rights reserved.
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
*   - Redistributions of source code must retain the above copyright
*     notice, this list of conditions and the following disclaimer.
*   - Redistributions in binary form must reproduce the above copyright
*     notice, this list of conditions and the following disclaimer in the
*     documentation and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
* ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
* DAMAGE.
*/
package format.abc;
import format.abc.Data;
import haxe.Int32;

private class NullOutput extends haxe.io.Output 
{
	public var n : Int;
	public function new() 
	{
		n = 0;
	}
	override function writeByte(c) 
	{
		n++;
	}
	override function writeBytes(b,pos,len) 
	{
		n += len;
		return len;
	}
}

class Context 
{
	public var curFunction : { f : Function, ops : Array<OpCode> };
	public var isExtending:Bool;
	var data : ABCData;
	var hstrings : Hash<Int>;
	var curClass : ClassDef;

	var classes : Array<Field>;
	var init : { f : Function, ops : Array<OpCode> };
	var fieldSlot : Int;
	var registers : Array<Bool>;
	public var bytepos : NullOutput;
	var opw : OpWriter;

	var classSupers: List<Index<Name>>;

	public var emptyString(default,null) : Index<String>;
	public var nsPublic(default,null) : Index<Namespace>;
	public var arrayProp(default, null) : Index<Name>;

	public function new()
	{
		classSupers = new List();
		bytepos = new NullOutput();
		opw = new OpWriter(bytepos);
		hstrings = new Hash();

		data = new ABCData();
		data.ints = new Array<Int32>();
		data.uints = new Array<Int32>();
		data.floats = new Array();
		data.strings = new Array();
		data.namespaces = new Array();
		data.nssets = new Array();
		data.metadatas = new Array();
		data.methodTypes = new Array();
		data.names = new Array();
		data.classes = new Array();
		data.functions = new Array();
		emptyString = string("");
		nsPublic = _namespace(NPublic(emptyString));
		arrayProp = name(NMultiLate(nsset([nsPublic])));

		classes = new Array();
		data.inits = new Array();
	}
	public function getData() 
	{
		return data;
	}
	function lookup<T>(arr:Array<T>, n:T):Index<T> 
	{
		for ( i in 0...arr.length ) 
			if (arr[i] == n) 
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}
	function elookup <T> ( arr:Array<T>, n:T):Index<T>
	{
		for( i in 0...arr.length )
			if( Type.enumEq(arr[i],n) )
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}
	/*
	function elookup2(n)
	{
		var arr = data.names;
		var nParams = Type.enumParameters(n);
		for( i in 0...arr.length )
		{
			var itemParams = Type.enumParameters(arr[i]);
			var t=0;
			if(itemParams.length==nParams.length)
				for(j in 0...itemParams.length)
				{
					if(Type.enumParameters(itemParams[j])[0]==Type.enumParameters(nParams[j])[0])
						t++;
					else
						break;
				}
			if(t==itemParams.length)
				return Idx(i + 1);
		}
		arr.push(n);
		return Idx(arr.length);
	}
	*/
	public function int(n):Index<Int32>
	{
		//return lookup(data.ints, i);
		var arr = data.ints;
		for ( i in 0...arr.length ) 
		{
			//if (Int32.compare(cast arr[i], Int32.ofInt(cast n)) == 0) 
			if (Int32.compare(arr[i], n) == 0) 
				return Idx(i + 1);
		}
		arr.push(n);
		return Idx(arr.length);
	}
	public function uint(n):Index<Int32>
	{
		//return lookup(data.uints,i);
		var arr = data.uints;
		for ( i in 0...arr.length ) 
		{
			if (Int32.compare(cast arr[i], Int32.ofInt(cast n)) == 0) 
			return Idx(i + 1);
		}			
		arr.push(n);
		return Idx(arr.length);
	}
	public function float(f):Index<Float>
	{
		//return lookup(data.floats,f);
		var arr=data.floats;
		for ( i in 0...arr.length ) 
			if (arr[i] == f) 
				return Idx(i + 1);
		arr.push(f);
		return Idx(arr.length);
	}
	public function string( s : String ) : Index<String> 
	{
		var n = hstrings.get(s);
		if( n == null ) 
		{
			data.strings.push(s);
			n = data.strings.length;
			hstrings.set(s,n);
		}
		return Idx(n);
	}
	public function _namespace(n) :Index<Namespace>
	{
		//return lookup(data.namespaces,n);
		var arr = data.namespaces;
		for( i in 0...arr.length )
			if( Type.enumEq(arr[i],n) )
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}
	public function nsset( ns : NamespaceSet ) : Index<NamespaceSet> 
	{
		for( i in 0...data.nssets.length ) 
		{
			var s = data.nssets[i];
			if( s.length != ns.length )
				continue;
			var ok = true;
			for( j in 0...s.length )
			if( !Type.enumEq(s[j],ns[j]) ) 
			{
				ok = false;
				break;
			}
			if( ok )
				return Idx(i + 1);
		}
		data.nssets.push(ns);
		return Idx(data.nssets.length);
	}
	public function name(n):Index<Name>
	{
		//return lookup(data.names,n);
		var arr = data.names;
		for( i in 0...arr.length )
			if( Type.enumEq(arr[i],n) )
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}
	public function type(path:String) /*: Null < Index < Name >>*/ 
	{
		if (path != null && path.indexOf(' params:') != -1)
		return typeParams(path);
		if( path == "*")
		return null;
		var patharr = path.split(".");
		var cname = patharr.pop();
		var ns = patharr.join(".");
		var pid = string(ns);
		var nameid = string(cname);
		var pid = _namespace(NPublic(pid));
		var tid = name(NName(nameid,pid));
		return tid;
	}
	public function typeParams(path:String) /*: Null < Index < Name >>*/ 
	{
		if( path == "*")
		return null;
		var parts:Array<String> = path.split(' params:');
		
		var _path = parts[0];
		var __path = this.type(_path);
		
		var _params:Array<String> = parts[1].split(',');
		var __params: Array<IName>= new Array();
		for (i in 0..._params.length)
		__params.push(this.type(_params[i]));

		var tid = name(NParams(__path, __params));
		return tid;
	}
	public function property(pname:String, ?ns) 
	{
		var tid;
		if (pname.indexOf(".") != -1)
		{
			tid = this.type(pname);
		}
		else
		{
			var pid = string("");
			var nameid = string(pname);
			var pid = if ( ns == null ) _namespace(NPublic(pid)) else ns;
			tid = name(NName(nameid,pid));
		}	
		return tid;
	}
	public function methodType(m) : Index<MethodType> 
	{
		data.methodTypes.push(m);
		return Idx(data.methodTypes.length - 1);
	}
	public function getClass(n) 
	{
		for ( i in 0...data.classes.length ) 
			if (data.classes[i] == n) 
				return Idx(i);
		throw('unknown class: '+n);
	}
	public function beginClass( path : String, ?isInterface:Bool ) 
	{
		classSupers = new List();
		if(!isInterface)
			beginFunction([],null);
		else
			beginInterfaceFunction([],null);
		ops([OThis,OScope]);
		init = curFunction;
		init.f.maxStack = 2;
		init.f.maxScope = 2;
		var script = { method : init.f.type, fields : new Array() };
		data.inits.push(script);// = [{method : init.f.type, fields : classes}];
		classes = script.fields;
		
		endClass();
		var tpath = this.type(path);
		/*
				beginFunction([],null);
				var st = curFunction.f.type;
				op(ORetVoid);
				endFunction();
				beginFunction([],null);
				var cst = curFunction.f.type;
				op(ORetVoid);
				endFunction();
				*/
		fieldSlot = 1;

		curClass = {
			name : tpath,
			superclass : this.type("Object"),
			interfaces : [],
			isSealed : false,
			isInterface : false,
			isFinal : false,
			_namespace : null,
			
			constructor : null,
			statics : null,
			/*
												constructor : cst,
												statics : st,*/
			fields : [],
			staticFields : [],
		};
		data.classes.push(curClass);
		classes.push(
		{
			name: tpath,
			slot: classes.length+1,//0,
			kind: FClass(Idx(data.classes.length - 1)),
			metadatas: null,
		});
		curFunction = null;
		return curClass;
	}
	
	public function endClass(?makeInit:Bool=true) 
	{
		if( curClass == null )
			return;
		endFunction();
		if (makeInit)
		{
			curFunction = init;
			ops([
			OGetGlobalScope,
			OGetLex( this.type("Object") ),
			]);
			// Add all class supers (if any)
			for (sup in classSupers)
				ops([OScope, OGetLex(sup)]);
			// Add final super class
			ops([
			OScope,
			OGetLex( curClass.superclass ),
			OClassDef( Idx(data.classes.length - 1) ),
			OPopScope,
			]);
			// Restore the scope
			for (sup in classSupers)
				op(OPopScope);
			// Add additional ops
			ops([
			OInitProp( curClass.name ),
			]);
			// Update our maxScope
			curFunction.f.maxScope += classSupers.length;
			op(ORetVoid);
			endFunction();
		}
		else
		{
			curFunction = init;
			op(ORetVoid);
			endFunction();
		}
		
		if (curClass.statics == null)
		{
			beginFunction([], null);//class initializer (static members)
			var st = curFunction.f.type;
			curClass.statics = st;
			curFunction.f.maxStack = 1;
			curFunction.f.maxScope = 1;
			op(OThis);
			op(OScope);
			op(ORetVoid);
			endFunction();
		} 
		curFunction = null;
		curClass = null;
	}
	public function addClassSuper(sup: String): Void 
	{
		if (curClass == null)
			return;
		classSupers.add(this.type(sup));
	}
	public function beginInterfaceMethod( mname : String, targs, tret, ?isStatic, ?isOverride, ?isFinal, ?willAddLater,  ?kind:MethodKind, ?extra,?ns:Index< Namespace > )
	{
		var m = beginInterfaceFunction(targs, tret, extra);
		if (willAddLater != true)
		{
			var fl = if( isStatic ) curClass.staticFields else curClass.fields;
			fl.push({
				name : property(mname, ns),
				slot : fl.length+1,//0,
				kind : FMethod(curFunction.f.type,kind,isFinal,isOverride),
				metadatas : null,
			});
		}
		return curFunction.f;
	}
	public function beginInterfaceFunction(args, ret, ?extra) 
	{
		endFunction();
		var f = {
			type : methodType({ args : args, ret : ret, extra : extra }),
			nRegs : args.length + 1,
			initScope : 0,
			maxScope : 0,
			maxStack : 0,
			code : null,
			trys : [],
			locals : [],
		};
		curFunction = { f : f, ops : [] };
		return Idx(data.methodTypes.length - 1);
	}
	public function beginFunction(args, ret, ?extra) : Index < Function > 
	{
		endFunction();
		var f = {
			type : methodType({ args : args, ret : ret, extra : extra }),
			nRegs : args.length + 1,
			initScope : 0,
			maxScope : 0,
			maxStack : 0,
			code : null,
			trys : [],
			locals : [],
		};
		curFunction = { f : f, ops : [] };
		data.functions.push(f);
		registers = new Array();
		for( x in 0...f.nRegs )
			registers.push(true);
		return Idx(data.functions.length - 1);
	}
	public function endFunction() 
	{
		if( curFunction == null )
		return;
		var old = opw.o;
		var bytes = new haxe.io.BytesOutput();
		opw.o = bytes;
		for( op in curFunction.ops )
			opw.write(op);
		curFunction.f.code = bytes.getBytes();
		opw.o = old;
		curFunction = null;
	}
	public function beginMethod( mname : String, targs, tret, ?isStatic, ?isOverride, ?isFinal, ?willAddLater,  ?kind:MethodKind, ?extra,?ns:Index< Namespace > )
	{
		var m = beginFunction(targs, tret, extra);
		if (willAddLater != true)
		{
			var fl = if( isStatic ) curClass.staticFields else curClass.fields;
			fl.push({
				name : property(mname, ns),
				slot : fl.length+1,//0,
				kind : FMethod(curFunction.f.type,kind,isFinal,isOverride),
				metadatas : null,
			});
		}
		return curFunction.f;
	}
	public function endMethod() 
	{
		endFunction();
	}
	public function defineField( fname : String, t:Null < IName > , ?isStatic, ?value : Value, ?_const : Bool,?ns:Index< Namespace >, ?slot:Null<Int>) : Slot// ?value : Value, ?_const : Bool added,?ns:Index< Namespace >,
	{
		var fl = if( isStatic ) curClass.staticFields else curClass.fields;
		var kind = FVar(t);
		if (value != null)
		{
			kind = FVar(t, value);
			if (_const)
				kind = FVar(t, value, _const);
		}
		fl.push({
			name : property(fname , ns),//ns added
			slot : if (slot == null)0 else slot,// if (isExtending)0 else fl.length + 1,//fieldSlot++;
			kind : kind,//value, _const added
			metadatas : null,
		});
		return fl.length;// fieldSlot;
	}
	public function op(o) 
	{
		curFunction.ops.push(o);
		opw.write(o);
	}
	public function ops( ops : Array<OpCode> ) 
	{
		for( o in ops )
			op(o);
	}
	public function switchDefault()
	{
		var ops = curFunction.ops;
		var pos = ops.length;
		
		var start = bytepos.n;
		var me = this;
		return function() 
		{
			ops[pos] = 
			switch(ops[pos])
			{
				default:
					OSwitch(0, []);
				case OSwitch(def, cases):
					OSwitch(me.bytepos.n - start, cases);
			}
		};
	}
	public function switchCase(index)
	{
		var ops = curFunction.ops;
		var pos = ops.length;
		var start = bytepos.n;
		var me = this;
		return function() 
		{
			ops[pos] = switch(ops[pos])
			{
				default:
					OSwitch(0, []);
				case OSwitch(def, cases):
					cases[index] = me.bytepos.n - start;
					OSwitch(def, cases);
			}
		};
	}
	public function backwardJump() 
	{
		var start = bytepos.n;
		var me = this;
		op(OLabel);
		return function(?jcond:Null<format.abc.JumpStyle>=null) 
		{
			if (jcond==null)
				return start - me.bytepos.n
			else
			{
				me.op(OJump(jcond, start - me.bytepos.n - 4));
				return 0;
			}
		};
	}
	/*
	public function backwardJump() 
	{
		var start = bytepos.n;
		var me = this;
		op(OLabel);
		return function(jcond:Null<format.abc.JumpStyle>, ?isSwitch:Bool = false) 
		{
			if (isSwitch)
				return start - me.bytepos.n
			else
			{
				me.op(OJump(jcond, start - me.bytepos.n - 4));
				return 0;
			}
		};
	}
	*/
	public function jump( jcond ) 
	{
		var ops = curFunction.ops;
		var pos = ops.length;
		op(OJump(JTrue,-1));
		var start = bytepos.n;
		var me = this;
		return function() {
			ops[pos] = OJump(jcond,me.bytepos.n - start);
		};
	}
	public function allocRegister() 
	{
		for( i in 0...registers.length )
		if( !registers[i] ) {
			registers[i] = true;
			return i;
		}
		registers.push(true);
		curFunction.f.nRegs++;
		return registers.length - 1;
	}
	public function freeRegister(i) 
	{
		registers[i] = false;
	}
	public function finalize() 
	{
		endClass();
		curFunction = init;
		op(ORetVoid);
		endFunction();
		curClass = null;
	}
}