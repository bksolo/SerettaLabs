// Ports library demo, blinks leds on all 4 ports in slightly different ways
// 2009-02-13 <jcw@equi4.com> http://opensource.org/licenses/mit-license.php
// $Id: blink_ports.pde 5402 2010-04-30 19:24:52Z jcw $

#include <Ports.h>
#include <RF12.h> // needed to avoid a linker error :(
#include <avr/sleep.h>
#include <OneWire.h>
#include <payload.h>

Port flowFloor (3); // The floorheating flow measurement
Port heaterPump (2); // gives power to the heater pump on the 
Port floorPump (2);  // the floor pump driver (fet) port 3 Dio
Port solarPump (3);  // the solar pump driver (fet) port 3 Aio
Port solarAuxPump (3); // second pump to get the solar loop going on port1 Aio

OneWire ds18b20 (6); // 1-wire temperature sensors, uses DIO port 4
// now that we have the port include code for reading
#include <tempSensors.h>

MilliTimer sendTimerPanel; // to time sending msgs 
MilliTimer auxHeatTimer; // to time sending msgs 
unsigned long receivedTime = 0; // to expire pump on message
byte needToSend = false;
boolean tempAsked = false;
casitaData payloadData;
roomBoard roomData;
//int panelOut; // holds the panel out temp
unsigned long cycleTimer; //timer for the panel pump cycle
volatile int NbTopsFan; //measuring the rising edges of the signal
int Calc;                               
int sensorPointer;  // pointer to step though sensors
boolean auxHeater = false;

// sensors we will read here
SensorInfo sensors[5] = {
    {tankTopID, "tankTop"}, 
    {tankInID, "tankIn"},
    {xchangeOutID, "xchangeOut" },
    {afterHeaterID, "afterHeater" },
    {tankBottomID, "tankBottom"}, 
};

/**
 * Interupt controller for the flow meter
 */
void rpm ()     //This is the function that the interupt calls 
{ 
  NbTopsFan++;  //This function measures the rising and falling edge of the hall effect sensors signal
}


/**
 * Function receive data
 */
void receive () {
  // data from the thermostat
  if (rf12_recvDone() && rf12_crc == 0) {
    if ((RF12_HDR_MASK & rf12_hdr) == livingRoomID ) {
      roomBoard* buf =  (roomBoard*) rf12_data;

      payloadData.floorPump = buf->heat;
  //    payloadData.fpPwm = buf->fpwm;
  //    payloadData.solarPump = buf->solPump;
  //    payloadData.spPwm = buf->spwm;
      roomData.temp = buf->temp;
      roomData.auxHeat = buf->auxHeat;
      payloadData.panelOut = buf->panelOut;
          
      Serial.print("received thermostat packet: ");
      Serial.println(payloadData.floorPump ? "heat" : "no heat");
  //    Serial.println(payloadData.fpPwm);
  //    Serial.println(payloadData.solarPump ? "solPump" : "no solPump");
      receivedTime = millis();
    } else if (millis() > receivedTime + 30000) { //keep on for 30 seconds 
      // if no pump ON signal received for some time, turn off
      payloadData.floorPump = false;
      payloadData.solarPump = false;
      payloadData.panelOut = false;
    } else if ((RF12_HDR_MASK & rf12_hdr) == panelsID) { // from the panels
      panelData* buf =  (panelData*) rf12_data;

      payloadData.panelOut = buf->tempOut;
      Serial.print("received panels packet: ");
      Serial.println(payloadData.panelOut);
    }
  }
}
        
void setup() {
  Serial.begin(57600);
  Serial.println("\n[Casita]");
  
  rf12_config();
  rf12_easyInit(5); // throttle packet sending to at least 5 seconds apart

  floorPump.mode(OUTPUT); //port 2 DIO
  payloadData.floorPump = false;
  payloadData.fpPwm = 100;

  solarAuxPump.mode2(OUTPUT); //port 3 AIO

  payloadData.panelOut = 0;
  payloadData.solarPump = false;
  payloadData.spPwm = 100;
  
  heaterPump.mode2(OUTPUT); //real mosfet plug port 2 AIO
  
  sensorPointer = 0; //start with the first sensor
  
  auxHeater = false;
}

#define minFloorInTemp 350
boolean heat = false;
boolean auxHeaterAskTemp = false;
byte heaterCounter = 0;

/**
 * The main loop
 */
void loop() {
  receive();
  
  if(payloadData.panelOut > payloadData.tankTop + 100) { // turn on if tankop + 10 degrees
    payloadData.solarPump = true;
  } else if(payloadData.tankIn < payloadData.tankTop + 20){ //turn off at tantop + 2 degrees
    payloadData.solarPump = false;
  }
  
  // overheat protection
  if(payloadData.tankTop >= tankMax) {
    auxHeater = false;
    payloadData.solarPump = false;
    Serial.println("gasheater & solarpump off");
  }
  
  if((payloadData.tankTop >= tankAuxMax)
    ||
    (payloadData.afterHeater >= afterHeaterMax))    auxHeater = false;

  solarAuxPump.digiWrite2(payloadData.solarPump);

  floorPump.digiWrite(payloadData.floorPump);

  if (payloadData.afterHeater >= afterHeaterMax) auxHeater = false;
  
  //run gas heater if tank too cold
  if(payloadData.tankTop < tankAuxMin || auxHeater) //payloadData.tankTop > 200
  {
    //make sure the heater comes on
    if(auxHeatTimer.poll(60000))
    {
      if(auxHeaterAskTemp)
      {
        Serial.print("set heaterTemp: ");
        Serial.println((int) payloadData.afterHeater);
        auxHeater = true;
        auxHeaterAskTemp = false;        
      }
      else
      {
        if(payloadData.afterHeater < payloadData.tankBottom+100) 
        {
          auxHeater = false;
          //if(heaterCounter++ >= 5) payloadData.errorCode = 1;
        }
        auxHeaterAskTemp = true;
      }
    }
  }    
  payloadData.heaterPump = auxHeater;
  heaterPump.digiWrite2(payloadData.heaterPump ); 
  
  if (tempAsked && tempTimerPanel.poll())
    {
       if(sensors[sensorPointer].desc == "tankTop") {
        payloadData.tankTop = readTemp1wire(sensors[sensorPointer].id);
      } else if(sensors[sensorPointer].desc == "tankIn") {
        payloadData.tankIn = readTemp1wire(sensors[sensorPointer].id);
      } else if(sensors[sensorPointer].desc == "xchangeOut") {
        payloadData.xchangeOut = readTemp1wire(sensors[sensorPointer].id);
      } else if(sensors[sensorPointer].desc == "afterHeater") {
        payloadData.afterHeater = readTemp1wire(sensors[sensorPointer].id);
      } else if(sensors[sensorPointer].desc == "tankBottom") {
        payloadData.tankBottom = readTemp1wire(sensors[sensorPointer].id);
      }      
      sensorPointer = (sensorPointer + 1) % 5;
      tempAsked = false;
    }
    else if(!tempAsked)
    {
      askTemp1Wire(sensors[sensorPointer].id);
      tempAsked = true;
      //set sensorwait timer
      tempTimerPanel.set(tempWaitTime);
    }
  
  if (sendTimerPanel.poll(1500)) {
    while (!rf12_canSend())
      rf12_recvDone();     
    rf12_sendStart(0, &payloadData, sizeof payloadData);
    Serial.print("gas heater :");
    Serial.print(payloadData.heaterPump ? "ON" : "OFF");
    Serial.print(" floorpump:");
    Serial.print(payloadData.floorPump ? "ON" : "OFF");
    Serial.print(" solarpump:");
    Serial.println(payloadData.solarPump ? "ON" : "OFF");
    Serial.print("tt:");
    Serial.print(payloadData.tankTop);
    Serial.print(" tb:");
    Serial.print(payloadData.tankBottom);
    Serial.print(" ah:");
    Serial.print(payloadData.afterHeater);
    Serial.print(" xo:");
    Serial.print(payloadData.xchangeOut);
    Serial.print(" po:");
    Serial.println(payloadData.panelOut);
  }
}
