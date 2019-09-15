//+------------------------------------------------------------------+
//|                                                    ExSystem2.mq5 |
//|                                          Copyright 2019, PxStrat |
//|                                        https://www.pxstrat.co.uk |
//+------------------------------------------------------------------+

#property copyright "Copyright 2019, PxStrat"
#property link      "https://www.pxstrat.co.uk "
#property version   "2.00"

//Include files
#include <Default/Trade/Trade.mqh>
#include <Default/Math/Stat/Math.mqh>

//Global variables
bool statusPosition = false;
input int distSL = 200;
input int distTP = 1000;
input double lot = 0.01;
ulong ticketNumber = 0;
double currentPrice = 0;
int positionType = 0;
double startPrice = 0;

datetime openTime;
input int holdingLength = 60;

//Global Structures
MqlRates dataRates[31];
MqlTradeRequest requestData;
MqlTradeResult resultData;
MqlTradeCheckResult checkData;

//Global classes
CTrade tradeObject;

//--- Expert initialization function
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }
 
//--- Expert deinitialization function
void OnDeinit(const int reason)
  {
  }

//--- Expert tick function
void OnTick()
  {
   if(statusPosition == false)
     {
      //--- Time filters
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(),currentTime);
      if(currentTime.day_of_week == 1 && currentTime.hour <= 4) return; //Avoid trading before 0700 CET
      if(currentTime.hour >= 19) return; //Avoid trading after 1900 CET
      if(currentTime.sec != 0) return;
      
      //Only enter a trade if the spread is low
      //MqlTick lastTick;
      //SymbolInfoTick(Symbol(),lastTick);
      //if((lastTick.ask-lastTick.bid) / Point() > 10) return;
      
      //--- Long Signal
      double signal = MathRandomNonZero();
      if(signal > 0.5)
        {
         tradeObject.Buy(lot);

         openTime = TimeCurrent();
         statusPosition = true;
         return;
         
        }
      
      //--- Short Signal
      if(signal <= 0.5)
        {
         tradeObject.Sell(lot);
         
         openTime = TimeCurrent();
         statusPosition = true;
         return;  
        }
     
      return;
     }
   
   if(statusPosition == true)
     {
      ticketNumber = PositionGetTicket(0);
      currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      positionType = (int)PositionGetInteger(POSITION_TYPE);
      startPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      //Comment("Current Price: ",currentPrice);
      
      //If after 21 o'clock
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(),currentTime);
      
      //Close any trades after
      if(currentTime.day_of_week == 5 && currentTime.hour >= 21)
        {
         tradeObject.PositionClose(ticketNumber);
         statusPosition = false;
         return;
        }
      
      //Close any trades after holding length has been reached
      if( (TimeCurrent() - openTime)/60 >= holdingLength)
        {
         tradeObject.PositionClose(ticketNumber);
         statusPosition = false;
         return;
        }
      
      if(positionType == POSITION_TYPE_BUY)
        {
         if(currentPrice - startPrice <= -distSL*Point())
           {
            tradeObject.PositionClose(ticketNumber);
            statusPosition = false;
            return;
           }
         if(currentPrice - startPrice >= distTP*Point())
           {
            tradeObject.PositionClose(ticketNumber);
            statusPosition = false;
            return;
           }  
        }
      
      if(positionType == POSITION_TYPE_SELL)
        {
         if(startPrice - currentPrice <= -distSL*Point())
           {
            tradeObject.PositionClose(ticketNumber);
            statusPosition = false;
            return;
           }
         if(startPrice - currentPrice >= distTP*Point())
           {
            tradeObject.PositionClose(ticketNumber);
            statusPosition = false;
            return;
           }  
        }  
      
     }  
  
  }
