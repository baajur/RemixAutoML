% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/EvalPlot.R
\name{EvalPlot}
\alias{EvalPlot}
\title{EvalPlot automatically builds calibration plots for model evaluation}
\usage{
EvalPlot(
  data,
  PredictionColName = c("PredictedValues"),
  TargetColName = c("ActualValues"),
  GraphType = c("calibration"),
  PercentileBucket = 0.05,
  aggrfun = function(x) mean(x, na.rm = TRUE)
)
}
\arguments{
\item{data}{Data containing predicted values and actual values for comparison}

\item{PredictionColName}{String representation of column name with predicted values from model}

\item{TargetColName}{String representation of column name with target values from model}

\item{GraphType}{Calibration or boxplot - calibration aggregated data based on summary statistic; boxplot shows variation}

\item{PercentileBucket}{Number of buckets to partition the space on (0,1) for evaluation}

\item{aggrfun}{The statistics function used in aggregation, listed as a function}
}
\value{
Calibration plot or boxplot
}
\description{
This function automatically builds calibration plots and calibration boxplots for model evaluation using regression, quantile regression, and binary and multinomial classification
}
\examples{
Correl <- 0.85
data <- data.table::data.table(Target = runif(100))
data[, x1 := qnorm(Target)]
data[, x2 := runif(100)]
data[, Independent_Variable1 := log(pnorm(Correl * x1 +
                                            sqrt(1-Correl^2) * qnorm(x2)))]
data[, Predict := (pnorm(Correl * x1 +
                           sqrt(1-Correl^2) * qnorm(x2)))]
EvalPlot(data,
         PredictionColName = "Predict",
         TargetColName = "Target",
         GraphType = "calibration",
         PercentileBucket = 0.05,
         aggrfun = function(x) quantile(x, probs = 0.50, na.rm = TRUE))
}
\seealso{
Other Model Evaluation and Interpretation: 
\code{\link{AutoLimeAid}()},
\code{\link{LimeModel}()},
\code{\link{ParDepCalPlots}()},
\code{\link{RedYellowGreen}()},
\code{\link{threshOptim}()}
}
\author{
Adrian Antico
}
\concept{Model Evaluation and Interpretation}
