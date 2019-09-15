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
#include <Default/Trade/PositionInfo.mqh>

//--- Input variables



//---Start of new variables
//Frequency of action variable
bool StatusTimer=false;

MqlDateTime timeCur, timePrev;
datetime timeCurDT, timePrevDT;

//Position book variables
CPositionInfo PosBook[];
int countPos=0, sizeReserve=1000;

//Strategy variables
ulong magicID[1] = {100000};

//Global classes
CTrade tradeObject;


//--- End of new variables

//Global variables
bool statusPosition = false;
input int distSL = 200;
input int distTP = 1000;
input int threshold = 300;
input double lot = 0.01;
ulong ticketNumber = 0;
double currentPrice = 0;
int positionType = 0;
double startPrice = 0;

//Global Structures
MqlRates dataRates[31];
MqlTradeRequest requestData;
MqlTradeResult resultData;
MqlTradeCheckResult checkData;


//Count
int count=0;

//--- Expert initialization function
int OnInit()
  {
   EventSetTimer(1); //Force timer right away
   return(INIT_SUCCEEDED);
  }
 
//--- Expert deinitialization function
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTick()
  {
   
  }

//--- Expert OnTimer function
void OnTimer()
  {
   Comment("Status Timer: ",StatusTimer," Current Time: ",TimeCurrent());
   //Ensure timer is set correctly
   if(StatusTimer==false)
     {
      EventKillTimer(); //Eliminate previous timer if one existed
      MqlDateTime currentTime; TimeToStruct(TimeGMT(),currentTime); //Define variables
      //If inside of GMT trading hours, set a 60s timer
      if(currentTime.day_of_week>0 && currentTime.day_of_week<6)
        {
         if(currentTime.sec == 0) //If current time is exactly at the start of the minute
           {
            //Set a 60s timer and set status to true
            EventSetTimer(60);
            StatusTimer=true;
           }
         else EventSetTimer(60-currentTime.sec); //Set timer for the full minute
        }
     }
   if(StatusTimer==true)
     {
      MqlDateTime currentTime; TimeToStruct(TimeGMT(),currentTime); //Define variables
      //Check that timer is within the trading hours, otherwise set timer 
      if(currentTime.day_of_week<1 || currentTime.day_of_week>5)
        {
         EventKillTimer(); //Eliminate previous timer
         StatusTimer=false; //Set status variable to false
         //Calculate time until next trading session starts
         MqlDateTime futureTime;
         for(int i=0; i<604800; i++)
           {
            TimeToStruct(TimeGMT()+i,futureTime);
            if(futureTime.day_of_week==1)
              {
               EventSetTimer(i);
               return;
              }
           }
         Comment("Error: No timer set!");
         return;  
        }
     }
   
   //Update the position book for this expert advisor
   ArrayResize(PosBook,PositionsTotal(),sizeReserve);
   countPos=0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      PosBook[countPos].SelectByTicket(PositionGetTicket(i));
      for(int u=0; u<ArraySize(magicID); u++)
        {
         if(PosBook[countPos].Magic() == magicID[u])
           {
            countPos++;
            break;
           }
        }
     }
   ArrayResize(PosBook,countPos,sizeReserve);
   Comment("Total Positions: ",countPos," Current Time: ",TimeCurrent());
   
   
   if(statusPosition == false)
     {
      //--- Time filters

      TimeToStruct(TimeCurrent(),timeCur);
      if(timeCur.hour <= 7) return; //Avoid trading before 0700 CET
      if(timeCur.hour >= 19) return; //Avoid trading after 1900 CET
      if(timeCur.min != 0) return; //Only trade at every full hour
      if(timeCur.sec != 0) return; //Only trade at every full hour
      if(timeCur.hour != 13) return; // Only trade at 1300 CET
      
      //Only enter a trade if the spread is low
      //MqlTick lastTick;
      //SymbolInfoTick(Symbol(),lastTick);
      //if((lastTick.ask-lastTick.bid) / Point() > 10) return;
      
      //--- Data retrieval
      int barsCopied = CopyRates(Symbol(),PERIOD_M1,0,31,dataRates);
      
      //--- Evaluate movement
      int movement = (int)MathRound((dataRates[30].close - dataRates[0].open)/Point());
      
      //--- Long Signal
      if(movement > 0)
        {
         requestData.action = TRADE_ACTION_DEAL;
         requestData.sl = 0;
         requestData.tp = 0;
         requestData.symbol = Symbol();
         requestData.type = ORDER_TYPE_BUY;
         requestData.volume = lot;
         requestData.type_filling = ORDER_FILLING_FOK;
         requestData.type_time = ORDER_TIME_GTC;
         requestData.comment = (string)magicID[0];
         requestData.magic = magicID[0];
         
         if(OrderCheck(requestData,checkData))
           {
            if(!OrderSend(requestData,resultData))
              {
               Print("Error");
               return;
              }
            statusPosition = true;
            return;
           }
         
        }
      
      //--- Short Signal
      if(movement <= 0)
        {
         requestData.action = TRADE_ACTION_DEAL;
         requestData.sl = 0;
         requestData.tp = 0;
         requestData.symbol = Symbol();
         requestData.type = ORDER_TYPE_SELL;
         requestData.volume = lot;
         requestData.type_filling = ORDER_FILLING_FOK;
         requestData.type_time = ORDER_TIME_GTC;
         requestData.comment = (string)magicID[0]; 
         requestData.magic = magicID[0];
         
         if(OrderCheck(requestData,checkData))
           {
            if(!OrderSend(requestData,resultData))
              {
               Print("Error");
               return;
              }
            statusPosition = true;
            return;  
           }
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
