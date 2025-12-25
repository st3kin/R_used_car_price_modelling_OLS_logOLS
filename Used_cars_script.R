# Setup

rm(list = ls())

#install.packages(c("tidyverse", "caret"))
library(tidyverse)
library(caret)

# Setting working directory

setwd("~/Desktop/Projects/R Projects/Used_cars_project/CSV_files")

list.files()

# Loading the csv files

audi <- read_csv("audi.csv", show_col_types = FALSE)
bmw <- read_csv("bmw.csv", show_col_types = FALSE)
ford <- read_csv("ford.csv", show_col_types = FALSE)
mercedes <- read_csv("merc.csv", show_col_types = FALSE)
skoda <- read_csv("skoda.csv", show_col_types = FALSE)
toyota <- read_csv("toyota.csv", show_col_types = FALSE)
volkswagen <- read_csv("vw.csv", show_col_types = FALSE)

# Adding a brand column to combine cleanly

audi <- audi %>% mutate(brand = "Audi")
bmw <- bmw %>% mutate(brand = "BMW")
ford <- ford %>% mutate(brand = "Ford")
mercedes <- mercedes %>% mutate(brand = "Mercedes")
skoda <- skoda %>% mutate(brand = "Skoda")
toyota <- toyota %>% mutate(brand = "Toyota")
volkswagen <- volkswagen %>% mutate(brand = "Volkswagen")

cars <- bind_rows(audi, bmw, ford, mercedes, skoda, toyota, volkswagen)

glimpse(cars)
summary(cars)

# Cleaning

current_year <- as.integer(format(Sys.Date(), "%Y"))

cars <- cars %>%
  mutate(
    age = current_year - year,
    transmission = as.factor(transmission),
    fuelType = as.factor(fuelType),
    model = as.factor(model),
    brand = as.factor(brand)
  )

# Removing obviously invalid/extreme values

cars_clean <- cars %>%
  filter(
    price > 0,
    mileage >= 0,
    engineSize > 0,
    mpg > 0,
    age >= 0,
    age <= 30,
    mileage <= 300000
  ) %>%
  drop_na(price, mileage, mpg, engineSize, tax, age, transmission, fuelType, model, brand)

cat("Rows before:", nrow(cars), "\n")
cat("Rows after:", nrow(cars_clean), "\n")

# Train/Test split

set.seed(42)
idx <- createDataPartition(cars_clean$price, p = 0.80, list = FALSE)
train <- cars_clean[idx, ]
test <- cars_clean[-idx, ]

# Sanity check

stopifnot(exists("train"))
stopifnot(nrow(train) > 0)

# Fitting an OLS model

ols <- lm(price ~ age + mileage + mpg + engineSize + tax + transmission + fuelType + brand,
          data = train)

summary(ols)

# Plotting residuals

diag_df <- data.frame(
  fitted = fitted(ols),
  resid = resid(ols)
)

ggplot(diag_df, aes(x = fitted, y = resid)) +
  geom_point(alpha = 0.25) +
  geom_hline(yintercept = 0) +
  geom_smooth(se = FALSE) +
  labs(
    title = "Residuals vs Fitted (OLS)",
    x = "Fitted (Predicted) price",
    y = "Residual (Actual - Predicted)"
  )

"\n
The residuals vs fitted plot indicates heteroskedasticity, with increasing error variance at higher 
predicted prices, as well as evidence of non-linearity. This suggests that the OLS assumptions of 
constant variance and linearity are violated, motivating a transformation of the response variable 
or alternative modeling approaches.
\n"

# Log-transforming the target

ols_log <- lm(log(price) ~ age + mileage + mpg + engineSize + tax + transmission + fuelType + brand,
       data = train)

summary(ols_log)

# Plotting residuals for the log model

diag_log <- data.frame(
  fitted = fitted(ols_log),
  resid = resid(ols_log)
)

ggplot(diag_log, aes(x = fitted, y = resid)) +
  geom_point(alpha = 0.25) +
  geom_hline(yintercept = 0) +
  geom_smooth(se = FALSE) +
  labs(
    title = "Residuals vs Fitted (log-price OLS)",
    x = "Fitted (Predicted) log(price)",
    y = "Residual (Actual - Predicted) in log space"
  )

# Predicting log(price) then converting back to price

test$pred_log <- predict(ols_log, newdata = test)
test$pred_price_from_log <- exp(test$pred_log)

rmse_log <- sqrt(mean((test$price - test$pred_price_from_log)^2))
mae_log <- mean(abs(test$price - test$pred_price_from_log))

cat("Test RMSE (log model, back-transformed):", round(rmse_log, 2), "\n")
cat("Test MAE (log model, back-transformed):", round(mae_log, 2), "\n")

"\n
An initial OLS model exhibited heteroskedasticity and non-linearity, as evidenced by a funnel-shaped 
residuals vs fitted plot. A log-transformation of the response variable was therefore applied. The 
transformed model demonstrated substantially improved residual behavior, with more constant variance 
and reduced curvature. 

Additionally, model fit improved, with test RMSE decreasing from approximately 
£4,800 to £4,300. Coefficients in the log model are interpretable as approximate percentage effects, 
providing more stable and meaningful insights across the price range.
\n"




