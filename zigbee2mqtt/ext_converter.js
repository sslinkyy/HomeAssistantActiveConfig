const fz = require('zigbee-herdsman-converters/converters/fromZigbee');
const tz = require('zigbee-herdsman-converters/converters/toZigbee');
const exposes = require('zigbee-herdsman-converters/lib/exposes');
const reporting = require('zigbee-herdsman-converters/lib/reporting');
const extend = require('zigbee-herdsman-converters/lib/extend');
const e = exposes.presets;
const ea = exposes.access;
const legacy = require('zigbee-herdsman-converters/lib/legacy');

const tuya = require('zigbee-herdsman-converters/lib/tuya');

const dataTypes = {
	raw: 0, // [ bytes ]
	bool: 1, // [0/1]
	number: 2, // [ 4 byte value ]
	string: 3, // [ N byte string ]
	enum: 4, // [ 0-255 ]
	bitmap: 5, // [ 1,2,4 bytes ] as bits
};

const dpMap = {
	dpPresenceState: 112, //æ˜¯å ¦å­˜åœ¨ï¼Œä»…ä¸ŠæŠ¥
	dpState: 105, //æ„Ÿåº”çŠ¶æ€ 
	dpMoveSensitivity: 106, //ç µæ• åº¦
	dpPresenceSensitivity: 111, //ç µæ• åº¦

	dpTimeout: 110, //æ„Ÿåº”å»¶è¿Ÿ

	dpDistance: 109, //ç›®æ ‡è· ç¦»


	dpRange: 107, //æœ€è¿œè· ç¦»èŒƒå›´
	dpIlluminanceLux: 104, //å…‰ç…§åº¦




};
const fzLocal = {
	cluster: 'manuSpecificTuya',
	type: ['commandDataResponse', 'commandDataReport'],
	convert: (model, msg, publish, options, meta) => {
		const dp = msg.data.dpValues[0].dp;
		const data = msg.data;
		const value = legacy.getDataValue(data.dpValues[0]);
		const result = {};

		switch (dp) {
			case dpMap.dpPresenceState:
				result.presence = value ? true : false;
				break;
			case dpMap.dpMoveSensitivity: 
				result.move_sensitivity = (value / 10);
				break;
			case dpMap.dpPresenceSensitivity: 
				result.presence_sensitivity = (value / 10);
				break;
			case dpMap.dpRange: 
				result.radar_range = (value / 100);
				break;
			case dpMap.dpDistance: 
				result.distance = (value / 100);
				break;
			case dpMap.dpTimeout: 
				result.presence_timeout = (value);
				break;
			case dpMap.dpIlluminanceLux: 
				result.illuminance_lux = (value);
				break;

			case dpMap.dpState:
				result.state = {
					0: 'none',
					1: 'presence',
					2: 'move'
				} [value];
				break;
		}
		return result;
	},
}
const tzLocal = {
	key: [
		'move_sensitivity',
		'presence_sensitivity',
		'radar_range',
		'presence_timeout',

	],
	convertSet: async (entity, key, value, meta) => {

		switch (key) {
			case 'move_sensitivity':
				await legacy.sendDataPointValue(entity, dpMap.dpMoveSensitivity, value);
				break;
			case 'presence_sensitivity':
				await legacy.sendDataPointValue(entity, dpMap.dpPresenceSensitivity, value);
				break;
			case 'radar_range':
				await legacy.sendDataPointValue(entity, dpMap.dpRange, value * 100);
				break;
			case 'presence_timeout':
				await legacy.sendDataPointValue(entity, dpMap.dpTimeout, value);
				break;

		}
		return {
			key: value
		};
	},

}


module.exports = [{
	fingerprint: [{
		modelID: 'TS0601',
		manufacturerName: '_TZE204_ijxvkhd0',
	}],
	model: 'ZY-M100-24G',
	vendor: 'TuYa',
	description: '24G Micro Motion Sensor',
	fromZigbee: [fzLocal],
	toZigbee: [tzLocal],
	onEvent: legacy.onEventSetLocalTime,
	exposes: [

		exposes.enum('state', ea.STATE, ['none', 'presence', 'move'])
		.withDescription('Presence State'),

		e.presence(),


		exposes.numeric('distance', ea.STATE)
		.withDescription('Distance'),

		e.illuminance_lux(),
		exposes.numeric('move_sensitivity', ea.STATE_SET).withValueMin(1)
		.withValueMax(10)
		.withValueStep(1)
		.withDescription('Motion Sensitivity'),

		exposes.numeric('presence_sensitivity', ea.STATE_SET).withValueMin(1)
		.withValueMax(10)
		.withValueStep(1)
		.withDescription('Presence Sensitivity'),

		exposes.numeric('radar_range', ea.STATE_SET).withValueMin(1.5)
		.withValueMax(5.5)
		.withValueStep(1)
		.withUnit('m').withDescription('Detection Range'),


		exposes.numeric('presence_timeout', ea.STATE_SET).withValueMin(1)
		.withValueMax(1500)
		.withValueStep(1)
		.withUnit('s').withDescription('Presence Time Out'),



	],
	meta: {
		multiEndpoint: true,
		tuyaDatapoints: [



			[112, 'presence', tuya.valueConverter.trueFalse1],
			[106, 'move_sensitivity', tuya.valueConverter.divideBy10],
			[111, 'presence_sensitivity', tuya.valueConverter.divideBy10],

			[107, 'radar_range', tuya.valueConverter.divideBy100],
			[109, 'distance', tuya.valueConverter.divideBy100],
			[110, 'presence_timeout', tuya.valueConverter.raw],
			[104, 'illuminance_lux', tuya.valueConverter.raw],
			[105, 'state', tuya.valueConverterBasic.lookup({
				'none': 0,
				'presence': 1,
				'move': 2
			})],

		],
	},


}, ];