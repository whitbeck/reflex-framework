package flight.position
{
	import flash.events.EventDispatcher;
	
	import flight.events.PropertyEvent;
	
	public class Position extends EventDispatcher implements IPosition
	{
		[Bindable]
		public var stepSize:Number = 1;
		
		[Bindable]
		public var skipSize:Number = 2;
		
		public var precision:Number = stepSize;
		
		private var _value:Number = 0;
		private var _percent:Number = 0;
		private var _size:Number = 10;
		private var _min:Number = 0;
		private var _max:Number = _size;
		private var _space:Number = 0;
		
		[Bindable(event="valueChange")]
		public function get value():Number
		{
			return _value;
		}
		public function set value(value:Number):void
		{
			value = value <= _min ? _min : (value >= _max - _space ? _max - _space : value);
			var p:Number = 1 / precision;
			value = Math.round(value * p) / p;
			if (_value == value) {
				return;
			}
			
			var oldValues:Array = [_value, _percent];
			_value = value;
			_percent = _size == 0 ? 1 : (_value - _min) / _size;
			
			PropertyEvent.dispatchChangeList(this, ["value", "percent"], oldValues);
		}
		
		[Bindable(event="percentChange")]
		public function get percent():Number
		{
			return _percent;
		}
		public function set percent(value:Number):void
		{
			if (_percent == value) {
				return;
			}
			
			this.value = _min + value * _size;
		}
		
		[Bindable(event="sizeChange")]
		public function get size():Number
		{
			return _size;
		}
		public function set size(value:Number):void
		{
			value = value <= 0 ? 0 : value;
			var p:Number = 1 / precision;
			value = Math.round(value * p) / p;
			if (_size == value) {
				return;
			}
			
			var oldValues:Array = [_size, _max];
			_size = value;
			_max = _min + _space + _size;
			
			value = value;
			PropertyEvent.dispatchChangeList(this, ["size", "max"], oldValues);
		}
		
		[Bindable(event="minChange")]
		public function get min():Number
		{
			return _min;
		}
		public function set min(value:Number):void
		{
			var p:Number = 1 / precision;
			value = Math.round(value * p) / p;
			if (_min == value) {
				return;
			}
			
			var properties:Array = ["min", "size"];
			var oldValues:Array = [_min, _size];
			_min = value;
			
			if (_max < _min) {
				properties.push("max");
				oldValues.push(_max);
				_max = _min;
			}
			if (_space > _max - _min) {
				properties.push("space");
				oldValues.push(_space);
				_space = _max - _min;
			}
			_size = _max - _space - _min;
			
			value = value;
			PropertyEvent.dispatchChangeList(this, properties, oldValues);
		}
		
		[Bindable(event="maxChange")]
		public function get max():Number
		{
			return _max;
		}
		public function set max(value:Number):void
		{
			var p:Number = 1 / precision;
			value = Math.round(value * p) / p;
			if (_max == value) {
				return;
			}
			
			var properties:Array = ["max", "size"]
			var oldValues:Array = [_max, _size];
			_max = value;
			
			if (_min > _max) {
				properties.push("min");
				oldValues.push(_min);
				_min = _max;
			}
			if (_space > _max - _min) {
				properties.push("space");
				oldValues.push(_space);
				_space = _max - _min;
			}
			_size = _max - _space - _min;
			
			value = value;
			PropertyEvent.dispatchChangeList(this, properties, oldValues);
		}
		
		[Bindable(event="spaceChange")]
		public function get space():Number
		{
			return _space;
		}
		public function set space(value:Number):void
		{
			var maxSize:Number = _max - _min;
			value = value >= maxSize ? maxSize : value;
			var p:Number = 1 / precision;
			value = Math.round(value * p) / p;
			if (_space == value) {
				return;
			}
			
			var oldValues:Array = [_space, _size];
			_space = value;
			_size = _max - _space - _min;
			
			PropertyEvent.dispatchChangeList(this, ["space", "size"], oldValues);
		}
		
		public function forward():void
		{
			value += stepSize;
		}
		
		public function backward():void
		{
			value -= stepSize;
		}
		
		public function skipForward():void
		{
			value += skipSize;
		}
		
		public function skipBackward():void
		{
			value -= skipSize;
		}
	}
}