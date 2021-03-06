/* rf ids of boards */
#define panelsID 1
#define casitaID 30
#define livingRoomID 20
// define grassTimerID 
// define windControllerID 12

// errors structure
typedef struct {
    int id;
    const char* desc;
} errorStruct;

errorStruct errors[1] = {
    {1, "Gas heater won't start"},
};

/**
 * Data payload definition.
 */
typedef struct {
    int tankIn; //temp going into the tank
    int tankBottom; // temperature bottom of tank
    int tankTop; // temperature top of tank
    int xchangeIn; // temperature going in the tank / back from floor
    int xchangeOut; // temperature coming out of the tank
    int afterHeater; // temperature coming out of the tank
    int floorIn; // temperature going in the floor
    int floorFlow; // The water flow speed.
    int panelOut; // temperature panel out
    int errorCode; //error code 
    boolean solarPump; // pump on or off
    byte spPwm; // solar pump pwm
    boolean floorPump; // pump on or off
    byte fpPwm; // pump pwm;
    boolean heaterPump; //auxilary heater pump
} casitaData;

typedef struct {
    boolean pump; // pump on or off
    boolean needPump; //we need the pump
	boolean water; // is there water detected
    int tempIn; // temperature panel in
    int tempOut; // temperature panel out
    int tempAmb; // temperature outside
//    int panelFlow; // The water flow speed.
} panelData;

typedef struct {
    byte light;     // light sensor
    byte moved :1;  // motion detector
    byte humi  :7;  // humidity
    int temp   :10; // temperature
    int dTemp  ; // desired temp
    int panelOut; // relay the panel out temp
    byte lobat :1;  // supply voltage dropped under 3.1V	
    boolean heat  :1; //need heat to be turned on
    boolean auxHeat : 1; //allow aux heater to go on
} roomBoard;

typedef struct {
    int temp :10; 
} setTemp;

typedef struct {
	byte year; 	
	byte month; 
	byte day;
	byte hour;
	byte minute;
	byte second;
} timeSignal;


typedef struct {
	word volts;
	word amps;
	boolean dump;
} windControl;