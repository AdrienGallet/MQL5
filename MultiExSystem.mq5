//+------------------------------------------------------------------+
//|                                               MultiExSystem1.mq5 |
//|                                      Copyright 2019, PxStrat LLC |
//|                                        https://www.pxstrat.co.uk |
//+------------------------------------------------------------------+
//--- Program Details
#property copyright     "Copyright 2019, PxStrat LLC"
#property link          "https://www.pxstrat.co.uk"
#property description   "E-Mail: admin@pxstrat.co.uk"
#property icon          "\\Files\\PxStrat Files\\LogoPxStrat.ico"
#property version       "1.00"

//--- Global Definitions
#define NUMBER_OF_SYMBOLS 2 //Number of symbols
#define EXPERT_NAME MQL5InfoString(MQL5_PROGRAM_NAME) //Name of expert

//--- Include Standard Library
#include <Default/Trade/Trade.mqh>
CTrade   trade; //Load a class pointer

//--- Include custom libraries
#include "Include/Enums.mqh"
#include "Include/InitializeArrays.mqh"
#include "Include/Errors.mqh"
#include "Include/TradeSignals.mqh"
#include "Include/TradeFunctions.mqh"
#include "Include/ToString.mqh"
#include "Include/Auxiliary.mqh"

//--- External parameters of the Expert Advisor
sinput long   MagicNumber           = 777;      // Magic number
sinput int    Deviation             = 10;       // Slippage
//---
sinput string delimeter_00=""; // --------------------------------
sinput string Symbol_01             = "EURUSD"; // Symbol 1
input  int    IndicatorPeriod_01    = 5;        // |     Indicator period
input  double TakeProfit_01         = 100;      // |     Take Profit
input  double StopLoss_01           = 50;       // |     Stop Loss
input  double TrailingStop_01       = 10;       // |     Trailing Stop
input  bool   Reverse_01            = true;     // |     Position reversal
input  double Lot_01                = 0.1;      // |     Lot
input  double VolumeIncrease_01     = 0.1;      // |     Position volume increase
input  double VolumeIncreaseStep_01 = 10;       // |     Volume increase step
//---
sinput string delimeter_01=""; // --------------------------------
sinput string Symbol_02             = "NZDUSD"; // Symbol 2
input  int    IndicatorPeriod_02    = 5;        // |     Indicator period
input  double TakeProfit_02         = 100;      // |     Take Profit
input  double StopLoss_02           = 50;       // |     Stop Loss
input  double TrailingStop_02       = 10;       // |     Trailing Stop
input  bool   Reverse_02            = true;     // |     Position reversal
input  double Lot_02                = 0.1;      // |     Lot
input  double VolumeIncrease_02     = 0.1;      // |     Position volume increase
input  double VolumeIncreaseStep_02 = 10;       // |     Volume increase step

//--- Arrays for storing external parameters
string Symbols[NUMBER_OF_SYMBOLS];            // Symbol
int    IndicatorPeriod[NUMBER_OF_SYMBOLS];    // Indicator period
double TakeProfit[NUMBER_OF_SYMBOLS];         // Take Profit
double StopLoss[NUMBER_OF_SYMBOLS];           // Stop Loss
double TrailingStop[NUMBER_OF_SYMBOLS];       // Trailing Stop
bool   Reverse[NUMBER_OF_SYMBOLS];            // Position reversal
double Lot[NUMBER_OF_SYMBOLS];                // Lot
double VolumeIncrease[NUMBER_OF_SYMBOLS];     // Position volume increase
double VolumeIncreaseStep[NUMBER_OF_SYMBOLS]; // Volume increase step

//--- Array of indicator agent handles
int spy_indicator_handles[NUMBER_OF_SYMBOLS];
//--- Array of signal indicator handles
int signal_indicator_handles[NUMBER_OF_SYMBOLS];
//--- Data arrays for checking trading conditions
struct PriceData
  {
   double            value[];
  };
PriceData open[NUMBER_OF_SYMBOLS];      // Opening price of the bar
PriceData high[NUMBER_OF_SYMBOLS];      // High price of the bar
PriceData low[NUMBER_OF_SYMBOLS];       // Low price of the bar
PriceData close[NUMBER_OF_SYMBOLS];     // Closing price of the bar
PriceData indicator[NUMBER_OF_SYMBOLS]; // Array of indicator values
//--- Arrays for getting the opening time of the current bar
struct Datetime
  {
   datetime          time[];
  };
Datetime lastbar_time[NUMBER_OF_SYMBOLS];
//--- Array for checking the new bar for each symbol
datetime new_bar[NUMBER_OF_SYMBOLS];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Initializing external parameter arrays
   InitializeInputParameters();
//--- Initializing arrays of indicator handles
   InitializeArrayHandles();
//--- Get agent handles
   GetSpyHandles();
//--- Get indicator handles
   GetIndicatorHandles();
//--- Initialize the new bar
   InitializeArrayNewBar();
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Print the deinitialization reason to the journal
   Print(GetDeinitReasonText(reason));
//--- When deleting from the chart
   if(reason==REASON_REMOVE)
     {
      //--- Delete the indicator handles
      for(int s=NUMBER_OF_SYMBOLS-1; s>=0; s--)
        {
         IndicatorRelease(spy_indicator_handles[s]);
         IndicatorRelease(signal_indicator_handles[s]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Chart events handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // Event identifier
                  const long &lparam,   // Long type event parameter
                  const double &dparam, // Double type event parameter
                  const string &sparam) // String type event parameter
  {
//--- If this is a custom event
   if(id>=CHARTEVENT_CUSTOM)
     {
      //--- Exit if trading is not allowed
      if(CheckTradingPermission()>0)
         return;
      //--- If there was a tick event
      if(lparam==CHARTEVENT_TICK)
        {
         //--- Check signals and trade on them
         CheckSignalsAndTrade();
         return;
        }
     }
  }

//+------------------------------------------------------------------+
//| Checking signals and trading based on the new bar event          |
//+------------------------------------------------------------------+
void CheckSignalsAndTrade()
  {
//--- Iterate over all specified symbols
   for(int s=0; s<NUMBER_OF_SYMBOLS; s++)
     {
      //--- If trading for this symbol is allowed
      if(Symbols[s]!="")
        {
         //--- If the bar is not new, proceed to the next symbol
         if(!CheckNewBar(s))
            continue;
         //--- If there is a new bar
         else
           {
            //--- Get indicator data. If there is no data, proceed to the next symbol
            if(!GetIndicatorsData(s))
               continue;
            //--- Get bar data               
            GetBarsData(s);
            //--- Check the conditions and trade
            TradingBlock(s);
            //--- Trailing Stop
            ModifyTrailingStop(s);
           }
        }
     }
  }
//+------------------------------------------------------------------+
