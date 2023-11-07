//+------------------------------------------------------------------+
//|                                               Link Ol System.mq5 |
//|                                                           GivenM |
//|              https://github.com/gmakhobe/MQL5_Link_Ol_Trading_EA |
//+------------------------------------------------------------------+

//--- EA Imports
#include "mylib.mqh"
//--- System Input
input ENUM_TIMEFRAMES   EA_Timeframe = PERIOD_H4;
//--- Handlers
int                     HandlerSuperTrend;
int                     HandlerStochasticRSI;
int                     HandlerTradeDynamicIndex;
int                     HandlerAverageTrueRange;
//--- Global Varibles
int                     SuperTrendLookBackPeriod = 10;
int                     SuperTrendMultiplier = 3;
int                     StochasticRSILookBbackPeriod = 14;
int                     TradeDynamicIndexRSILookBack = 13;
int                     TradeDynamicIndexPriceLineLookBack = 2;
int                     TradeDynamicIndexTradeSignalLineLookBack = 7;
int                     TradeDynamicIndexMarketBaseLineLookBack = 34;
int                     AverageTrueRangeLookBack = 7;
int                     DayOfOpeningTrade;

double                  RiskToRewardRatio = 2.0;
double                  PercentageToRisk = 1.0;

datetime                PreviousTimeSaved;

bool                    CanOpenTrade = true;
bool                    IsTradeBuy = NULL;
bool                    IsTradeSell = NULL;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   HandlerSuperTrend = iCustom(Symbol(), EA_Timeframe, "SuperTrend", SuperTrendLookBackPeriod, SuperTrendMultiplier);
   HandlerStochasticRSI = iCustom(Symbol(), EA_Timeframe, "StochasticRSI", StochasticRSILookBbackPeriod, EA_Timeframe);
   HandlerTradeDynamicIndex = iCustom(Symbol(), EA_Timeframe, "DynamicTradersIndex", TradeDynamicIndexRSILookBack, TradeDynamicIndexPriceLineLookBack, TradeDynamicIndexTradeSignalLineLookBack, TradeDynamicIndexMarketBaseLineLookBack, EA_Timeframe);
   HandlerAverageTrueRange = iATR(Symbol(), EA_Timeframe, AverageTrueRangeLookBack);

   if(HandlerAverageTrueRange == INVALID_HANDLE || HandlerSuperTrend == INVALID_HANDLE || HandlerStochasticRSI == INVALID_HANDLE || HandlerTradeDynamicIndex == INVALID_HANDLE)
     {
      return INIT_FAILED;
     }

   ChartIndicatorAdd(ChartID(), 0, HandlerSuperTrend);
   ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(ChartID(), CHART_WINDOWS_TOTAL), HandlerStochasticRSI);
   ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(ChartID(), CHART_WINDOWS_TOTAL), HandlerTradeDynamicIndex);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(HandlerSuperTrend);
   IndicatorRelease(HandlerStochasticRSI);
   IndicatorRelease(HandlerTradeDynamicIndex);
   IndicatorRelease(HandlerAverageTrueRange);

   string indicatorSuperTrend;
   string indicatorStochasticRSI;
   string indicatorTradeDynamicIndex;

   StringConcatenate(indicatorSuperTrend, "SuperTrend(", SuperTrendLookBackPeriod,")");
   StringConcatenate(indicatorStochasticRSI, "stochasticRSI(", StochasticRSILookBbackPeriod,")");
   StringConcatenate(indicatorTradeDynamicIndex, "Traders Dynamic Index(", TradeDynamicIndexPriceLineLookBack, ",", TradeDynamicIndexRSILookBack,",", TradeDynamicIndexPriceLineLookBack,",", TradeDynamicIndexTradeSignalLineLookBack,",", TradeDynamicIndexMarketBaseLineLookBack,")");

   ChartIndicatorDelete(ChartID(), 0, indicatorSuperTrend);
   ChartIndicatorDelete(ChartID(), 1, indicatorStochasticRSI);
   ChartIndicatorDelete(ChartID(), 1, indicatorTradeDynamicIndex);


  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int barsCalculatedForSuperTrend = BarsCalculated(HandlerSuperTrend) / 2;
   int barsCalculatedForTradeDynamicIndex = BarsCalculated(HandlerTradeDynamicIndex) / 2;
   int barsCalculatedForAverageTrueRange = BarsCalculated(HandlerAverageTrueRange) / 2;

   double superTrendBufferTrendIndicator[];
   double stochasticRSIBufferIndicator[];
   double tradeDynamicIndexBufferIndicatorColorSignal[];
   double averageTrueRangeStop[];

   bool isTradeDynamicIndexUpTrend = NULL;
   bool isSuperTrendUpTrend = NULL;
   bool isStochasticRSIUpTrend = NULL;

   MqlRates priceRates[];

   datetime localTime = TimeLocal();

   MqlDateTime localTimeStruct;

   TimeToStruct(localTime, localTimeStruct);

   if(CopyRates(Symbol(), EA_Timeframe, 0, barsCalculatedForSuperTrend, priceRates) <= 0)
      return ;

   ArraySetAsSeries(priceRates, true);

   if(PreviousTimeSaved != priceRates[0].time)
     {
      if(!CopyBuffer(HandlerSuperTrend, 2, 0, barsCalculatedForSuperTrend, superTrendBufferTrendIndicator))
         return ;
      if(!CopyBuffer(HandlerStochasticRSI, 0, 0, barsCalculatedForSuperTrend, stochasticRSIBufferIndicator))
         return ;
      if(!CopyBuffer(HandlerTradeDynamicIndex, 1, 0, barsCalculatedForTradeDynamicIndex, tradeDynamicIndexBufferIndicatorColorSignal))
         return ;
      if(!CopyBuffer(HandlerAverageTrueRange, 0, 0, barsCalculatedForAverageTrueRange, averageTrueRangeStop))
         return ;

      ArraySetAsSeries(superTrendBufferTrendIndicator, true);
      ArraySetAsSeries(stochasticRSIBufferIndicator, true);
      ArraySetAsSeries(tradeDynamicIndexBufferIndicatorColorSignal, true);
      ArraySetAsSeries(averageTrueRangeStop, true);
      // Trade Signal For TDI
      if(tradeDynamicIndexBufferIndicatorColorSignal[0] >= 1)
        {
         isTradeDynamicIndexUpTrend = true;
        }
      else
        {
         isTradeDynamicIndexUpTrend = false;
        }
      // Trade Signal For SuperTrend
      if(superTrendBufferTrendIndicator[0] >= 1)
        {
         isSuperTrendUpTrend = true;
        }
      else
        {
         isSuperTrendUpTrend = false;
        }
      // Trade Signal for Stochastic
      if(stochasticRSIBufferIndicator[1] <= 20 && stochasticRSIBufferIndicator[0] >= 20)
        {
         isStochasticRSIUpTrend = true;
        }
      if(stochasticRSIBufferIndicator[1] >= 80 && stochasticRSIBufferIndicator[0] <= 80)
        {
         isStochasticRSIUpTrend = false;
        }

      //--- Buy Condition
      if(isTradeDynamicIndexUpTrend && isSuperTrendUpTrend && isStochasticRSIUpTrend && CanOpenTrade)
        {

         CanOpenTrade = false;
         DayOfOpeningTrade = localTimeStruct.day;
         IsTradeBuy = true;
        }
      //--- Sell Condition
      if(!isTradeDynamicIndexUpTrend && !isSuperTrendUpTrend && !isStochasticRSIUpTrend && CanOpenTrade)
        {
         CanOpenTrade = false;
         DayOfOpeningTrade = localTimeStruct.day;
         IsTradeSell = true;
        }

      PreviousTimeSaved = priceRates[0].time;
      
      buyMarket(averageTrueRangeStop[0]);
      sellMarket(averageTrueRangeStop[0]);
     }

//---Enable can open trades
   if(localTimeStruct.hour == 8 && CanOpenTrade == false && DayOfOpeningTrade != localTimeStruct.day)
     {
      CanOpenTrade = true;
     }

  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void buyMarket(double tradeStopLoss)
  {
   if(!IsTradeBuy)
     {
      return ;
     }

   double stopLoss = tradeStopLoss;
   double takeProfit = tradeStopLoss * RiskToRewardRatio;
   double lotSize = NormalizeDouble(onPositionSizeCalculate(PercentageToRisk, stopLoss), 2);
   
   openBuyOrder(Symbol(), lotSize, stopLoss, false, takeProfit, false);

   IsTradeBuy = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sellMarket(double tradeStopLoss)
  {
   if(!IsTradeSell)
     {
      return ;
     }
   
   double stopLoss = tradeStopLoss;
   double takeProfit = tradeStopLoss * RiskToRewardRatio;
   double lotSize = NormalizeDouble(onPositionSizeCalculate(PercentageToRisk, stopLoss), 2);

   openSellOrder(Symbol(),lotSize,stopLoss,false,takeProfit, false);

   IsTradeSell = false;
  }
//+------------------------------------------------------------------+
