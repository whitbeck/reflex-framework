package flight.binding
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import flight.events.PropertyEvent;
	import flight.utils.Type;
	
	import mx.core.IMXMLObject;
	
	public class Binding extends EventDispatcher implements IMXMLObject
	{
		public var applyOnly:Boolean = false;
		
		private var indicesIndex:Dictionary = new Dictionary(true);
		private var bindIndex:Dictionary = new Dictionary(true);
		
		private var explicitValue:Object;
		private var updating:Boolean;
		private var _value:*;
		private var _property:String;
		private var _sourcePath:Array;
		private var _resolved:Boolean;
		
		public function Binding(source:Object = null, sourcePath:String = null)
		{
			reset(source, sourcePath);
		}
		
		public function get property():String
		{
			return _property;
		}
		
		public function get resolved():Boolean
		{
			return _resolved;
		}
		
		public function get sourcePath():String
		{
			return _sourcePath.join(".");
		}
		public function set sourcePath(value:String):void
		{
			reset(getSource(0), value);
		}
		
		[Bindable(event="valueChange")]
		public function get value():*
		{
			return _value;
		}
		public function set value(value:*):void
		{
			if (_value == value || value === undefined) {
				return;
			}
			
			var oldValue:Object = _value;
			explicitValue = value;
			
			var source:Object = getSource(_sourcePath.length - 1);
			if (source == null) {
				return;
			}
			
			if (_property in source) {
				if (!applyOnly) {
					explicitValue = null;
				}
				source[_property] = value;
				
				if (_value == oldValue) {
					_value = value;
					PropertyEvent.dispatchChange(this, "value", oldValue, _value);
				}
			} else {
				var className:String = getQualifiedClassName(source).split("::").pop();
				trace("Warning: Binding access of undefined property '" + _property + "' in " + className + ".");
			}
		}
		
		public function bind(target:Object, property:String):Boolean
		{
			var bindList:Array = bindIndex[target];
			if (bindList == null) {
				bindList = bindIndex[target] = [];
			}
			
			if (bindList.indexOf(property) != -1) {
				return false;
			}
			
			bindList.push(property);
			target[property] = _value;
			return true;
		}
		
		public function unbind(target:Object, property:String):Boolean
		{
			var bindList:Array = bindIndex[target];
			if (bindList == null) {
				return false;
			}
			
			var i:int = bindList.indexOf(property);
			if (i == -1) {
				return false;
			}
			
			bindList.splice(i, 1);
			if (bindList.length == 0) {
				delete bindIndex[target];
			}
			return true;
		}
		
		public function bindListener(listener:Function, useWeakReference:Boolean = true):Boolean
		{
			addEventListener("valueChange", listener, false, 0, useWeakReference);
			PropertyEvent.dispatchChange(this, "value", _value, _value);
			return true;
		}
		
		public function unbindListener(listener:Function):Boolean
		{
			removeEventListener("valueChange", listener);
			return true;
		}
		
		public function hasBinds():Boolean
		{
			for (var target:* in bindIndex) {
				return true;
			}
			
			return hasEventListener("valueChange");
		}
		
		public function release():void
		{
			unbindPath(0);
		}
		
		public function reset(source:Object, sourcePath:String = null):void
		{
			unbindPath(0);
			
			if (sourcePath != null) {
				_sourcePath = sourcePath.split(".");
				_property = _sourcePath[ _sourcePath.length-1 ];
			}
			
			update(source, 0);
		}
		
		private function getSource(pathIndex:int = 0):Object
		{
			for (var source:* in indicesIndex) {
				if (indicesIndex[source] != pathIndex) {
					continue;
				}
				return source;
			}
			
			return null;
		}
		
		private function update(source:Object, pathIndex:int = 0):void
		{
			if (updating) {
				return;
			}
			
			updating = true;
			
			var oldValue:Object = _value;
			_value = bindPath(source, pathIndex);		// udpate full path
			
			if (oldValue != _value) {
				
				// update bound targets
				for (var target:* in bindIndex) {
					
					var bindList:Array = bindIndex[target];
					for (var i:int = 0; i < bindList.length; i++) {
						
						var prop:String = bindList[i];
						target[prop] = _value;
					}
				}
				// update bound listeners
				PropertyEvent.dispatchChange(this, "value", oldValue, _value);
			}
			
			updating = false;
		}
		
		private function bindPath(source:Object, pathIndex:int):*
		{
			if (_sourcePath.length == 0) {
				return source;
			}
			
			unbindPath(pathIndex);
			
			var prop:String;
			var len:int = (applyOnly && explicitValue != null) ? _sourcePath.length - 1 : _sourcePath.length;
			for (pathIndex; pathIndex < len; pathIndex++) {
				
				if (source == null) {
					break;
				}
				
				prop = _sourcePath[pathIndex];
				if ( !(prop in source) ) {
					var className:String = getQualifiedClassName(source).split("::").pop();
					trace("Warning: Binding access of undefined property '" + prop + "' in " + className + ".");
					break;
				}
				
				indicesIndex[source] = pathIndex;
				
				if (source is IEventDispatcher) {
					var changeEvents:Array = getBindingEvents(source, prop);
					for each (var changeEvent:String in changeEvents) {
						IEventDispatcher(source).addEventListener(changeEvent, onPropertyChange, false, 100, true);
					}
				} else {
					className = getQualifiedClassName(source).split("::").pop();
					trace("Warning: Property '" + prop + "' is not bindable in " + className + ".");
				}
				
				source = source[prop];
			}
			
			_resolved = Boolean(pathIndex == _sourcePath.length || source != null);
			if (!_resolved) {
				return;
			}
			
			if (explicitValue != null) {
				var tmpValue:Object = explicitValue;
				
				if (applyOnly && pathIndex == len) {
					indicesIndex[source] = pathIndex;
				} else {
					source = getSource(_sourcePath.length-1);
					if (!applyOnly) {
						explicitValue = null;
					}
				}
				
				prop = _sourcePath[_sourcePath.length-1];
				if (prop in source) {
					source = source[prop] = tmpValue;
				} else {
					trace("Warning: Binding access of undefined property '" + prop + "' in " + source + ".");
				}
			}
			
			return source;
		}
		
		private function unbindPath(pathIndex:int):void
		{
			for (var source:* in indicesIndex) {
				var index:int = indicesIndex[source];
				if (index < pathIndex) {
					continue;
				}
				
				if (source is IEventDispatcher) {
					var changeEvents:Array = getBindingEvents(source, _sourcePath[index]);
					for each (var changeEvent:String in changeEvents) {
						IEventDispatcher(source).removeEventListener(changeEvent, onPropertyChange);
					}
				}
				delete indicesIndex[source];
			}
		}
		
		private function onPropertyChange(event:Event):void
		{
			var source:Object = event.target;
			var pathIndex:int = indicesIndex[source];
			var prop:String = _sourcePath[pathIndex];
			update(source[prop], pathIndex+1);
		}
		
		
		// ====== STATIC MEMEBERS ====== //
		
		private static var descCache:Dictionary = new Dictionary();
		private static var bindingIndex:Dictionary = new Dictionary();
		
		public static function getBinding(source:Object, sourcePath:String):Binding
		{
			var bindingList:Array = bindingIndex[source];
			if (bindingList == null) {
				bindingList = bindingIndex[source] = [];
			}
			
			var binding:Binding = bindingList[sourcePath];
			if (binding == null) {
				binding = new Binding(source, sourcePath);
				bindingList[sourcePath] = binding;
			}
			
			return binding;
		}
		
		public static function releaseBinding(binding:Binding):Boolean
		{
			var source:Object = binding.getSource(0);
			var sourcePath:String = binding.sourcePath;
			
			return release(source, sourcePath);
		}
		
		public static function release(source:Object, sourcePath:String):Boolean
		{
			var bindingList:Array = bindingIndex[source];
			if (bindingList == null) {
				return false;
			}
			
			var binding:Binding = bindingList[sourcePath];
			if (binding == null) {
				return false;
			}
			
			delete bindingList[sourcePath];
			binding.release();
			
			return true;
		}
		
		public function initialized(document:Object, id:String):void
		{
			reset(document, sourcePath);
		}
		
		private static function getBindingEvents(target:Object, property:String):Array
		{
			var bindings:Array = describeBindings(target);
			if (bindings[property] == null) {
				bindings[property] = [property + "Change"];
			}
			return bindings[property];
		}
		
		private static function describeBindings(value:Object):Array
		{
			if ( !(value is Class) ) {
				value = value.constructor;
			}
			
			if (descCache[value] == null) {
				var desc:XMLList = Type.describeProperties(value, "Bindable");
				var bindings:Array = descCache[value] = [];
				
				for each (var prop:XML in desc) {
					var property:String = prop.@name;
					var changeEvents:Array = [];
					var bindable:XMLList = prop.metadata.(@name == "Bindable");
					
					for each (var bind:XML in bindable) {
						var changeEvent:String = (bind.arg.(@key == "event").length() != 0) ?
							bind.arg.(@key == "event").@value :
							changeEvent = bind.arg.@value;
						
						changeEvents.push(changeEvent);
					}
					
					bindings[property] = changeEvents;
				}
			}
			
			return descCache[value];
		}
		
	}
}