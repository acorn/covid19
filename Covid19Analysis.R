### Data on COVID-19 (coronavirus) by Our World in Data
### Data from git: https://github.com/CSSEGISandData/COVID-19

library(readr) #to read csv
library(knitr) #kable - formating & visualization
library(ggplot2)
library(ggcorrplot)
library(dplyr)
library(convertr)
library(scatterplot3d)
library(reshape2)
library(tidyverse)
library(xts)
library(superheat)
library(choroplethr)
library(choroplethrMaps)
library(maptools)
library(Holidays)
library(lubridate)
library(GISTools) #https://rstudio-pubs-static.s3.amazonaws.com/958_d3123f6a9f95436a8177dd096ad768a7.html


# cases, latest
latest_cases_data <- read.csv(file = "https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/latest/owid-covid-latest.csv")

#time series case data
cumulative_data <- read.csv(file = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv")

end <- ncol(cumulative_data)

#subset
cumulative_data_subset <- cumulative_data[c(2,5:end)]

#global deaths time series
global_deaths <- read.csv(file = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv")

#testing
testing_data <- read.csv(file = "https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/testing/covid-testing-all-observations.csv")

#vaccines
vaccination_data <- read.csv(file = "https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/vaccinations.csv")

countries <- as.data.frame(unique(cumulative_data_subset$Country.Region))

#modify column name
colnames(countries) <- "Country.Region"

#adding ISO code
country.iso <- as.data.frame(unique(vaccination_data[c(1:2)]))
#modify column names to facilitate join
colnames(country.iso) <- c("Country.Region", "ISO.code")

countries <- countries %>% left_join(country.iso)

#adding identity column
countries$ID <- seq.int(nrow(countries))


#merge the two frames c("a" = "b") will match x$a to y$b
cumulative_data_subset <- cumulative_data_subset %>% 
       left_join(countries)

cumulative_data_subset$ISO.code = NULL
cumulative_data_subset$Country.Region = NULL


###ADDING VACCINATION DATA
#subset vaccine data
vaccination.data.sub <- vaccination_data[c(1:3,8)]
colnames(vaccination.data.sub) <- 
  c("Country.Region", "ISO.code", "Date", "Daily.vaccinations")

vaccination.data.sub <- vaccination.data.sub %>%
                        left_join(countries)

vaccination.data.sub$Country.Region = NULL
vaccination.data.sub$ISO.code = NULL

vaccination.data.sub$Date = as.Date(vaccination.data.sub$Date)

###ADDING TESTING DATA
## subset test data
testing.data.sub <- testing_data[c(2,3,8)]
colnames(testing.data.sub) <- c("ISO.code", "Date", "Daily.tests")

#adding country metadata
testing.data.sub <- testing.data.sub %>% left_join(countries)

testing.data.sub$Date <- as.Date(testing.data.sub$Date)
testing.data.sub$Daily.tests <- as.numeric(testing.data.sub$Daily.tests)

###MELTING THE DATA!!
covid_melt <- melt(cumulative_data_subset, id.vars = "ID")

names(cumulative_data_subset)

covid_melt2 <- covid_melt %>% mutate_all(funs(str_replace(., "X", "")))

covid_melt3 <- covid_melt2 %>% mutate_at(c("variable"),funs(str_replace_all(., "\\.", "/")))

covid_melt4 <- covid_melt3 %>% 
               add_column( "Date" = as.Date(covid_melt3$variable, "%m/%d/%y"), 
                                           .after = "variable" )
covid_melt4$variable = NULL

#to numeric, ID & value
covid_melt4[, c(1,3)] <- sapply(covid_melt4[,c(1,3)], as.numeric)

###fold in vaccination data
## aggregate to one value per date to match vaccination data
covid_melt4.agg <- aggregate(covid_melt4$value, 
                             by=list(covid_melt4$ID, 
                                     covid_melt4$Date), 
                             sum)
colnames(covid_melt4.agg) <- c("ID", "Date", "value")

##Join vaccination data
covid_melt4.agg <- covid_melt4.agg %>% 
                left_join(vaccination.data.sub)

##Join testing data
covid_melt4.agg <- covid_melt4.agg %>%
                    left_join(testing.data.sub)


# sum of cases by date across all countries
covid.cases <- covid_melt4.agg[, c(2,3)] %>% na.omit() #cases
covid.tests <- covid_melt4.agg[, c(2,6)] %>% na.omit() #tests
covid.vaccines <- covid_melt4.agg[, c(2,4)] %>% na.omit() #vaccines

covid.cases <- aggregate(covid.cases$value, by=list(covid.cases$Date), sum)
colnames(covid.cases) = c("Date", "Cases")
covid.tests <- aggregate(covid.tests$Daily.tests, by=list(covid.tests$Date), sum)
colnames(covid.tests) = c("Date", "Tested")
covid.vaccines <- aggregate(covid.vaccines$Daily.vaccinations, 
                            by=list(covid.vaccines$Date), sum)
colnames(covid.vaccines) = c("Date", "Vaccinated")

combined.covid.curve <- covid.cases %>% 
                          left_join(covid.tests) %>%
                          left_join(covid.vaccines)

#Covid Cases
ggplot(combined.covid.curve, aes(Date, Cases, col=Cases)) +
         geom_point() +
         stat_smooth() +
         scale_y_continuous(label = scales::comma) + 
         labs(title = " Covid-19 Cases Worldwide",
         caption = "Source: Johns Hopkins University CSSE Covid-19 data",
         y = "Cases") + 
         theme_minimal()

#Testing 
ggplot(combined.covid.curve, aes(Date, Tested, col=Tested)) +
  geom_point() +
  stat_smooth() + 
  scale_y_continuous(label = scales::comma) + 
  labs(title = " Covid-19 Testing Worldwide",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data",
       y = "Tests") + 
  theme_minimal()


vaccination.data.sub <- subset(combined.covid.curve, Date >= "2020-12-01")
#Vaccinations
ggplot(vaccination.data.sub, aes(Date, Vaccinated, col=Vaccinated)) +
  geom_point() +
  stat_smooth() +
  scale_y_continuous(label = scales::comma) + 
  labs(title = " Covid-19 Vaccinations Worldwide",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data",
       y = "Vaccinations") + 
  theme_minimal()


#scatter plot to see trend in cases since first vaccination 
first.date.vaccine <- min(covid.vaccines$Date)
cases.over.time <- combined.covid.curve %>% 
               add_column( "days.since.1stdose" = 
                             (combined.covid.curve$Date - first.date.vaccine), 
                                           .after = "Vaccinated" )

cases.after.vaccine <- subset(cases.over.time, days.since.1stdose >= 0 )
cases.before.vaccine <- subset(cases.over.time, days.since.1stdose < 0)


ggplot (cases.before.vaccine, 
        aes(x = days.since.1stdose, 
            y = Cases)) +
  geom_point() +
  geom_smooth(color = "tomato") +
  scale_y_continuous(label = scales::comma) + 
  labs(title = "Worldwide Covid-19 Cases before Vaccines",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data",
       x = "Days before first dose",
       y = "Covid-19 cases") + 
  theme_minimal()

ggplot(cases.after.vaccine, 
       aes(x = days.since.1stdose, 
           y = Cases)) +
  geom_point() + 
  geom_smooth(color = "orange") +
  scale_y_continuous(label = scales::comma) + 
  labs(title = "Worldwide Covid-19 Cases after Vaccines",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data",
       x = "Days after first dose",
       y = "Covid-19 cases") + 
  theme_minimal()

#####CHOROPLETH
covid.cases.by.country <- aggregate(covid_melt4$value, 
                             by=list(covid_melt4$ID), 
                             sum)
colnames(covid.cases.by.country) <- c("ID", "value")

covid.cases.by.country <- covid.cases.by.country %>% left_join(countries)

covid.cases.by.country2 <- covid.cases.by.country[, c("Country.Region", "value")]

colnames(covid.cases.by.country2) <- c("region", "value")

covid.cases.by.country2$region <- tolower(covid.cases.by.country2$region) 

covid.cases.by.country2 <- covid.cases.by.country2 %>%
mutate(region = recode(region,
                      "us" = "united states of america",
                      "congo (brazzaville)" = "democratic republic of the congo",
                      "congo (kinshasa)" = "republic of congo",
                      "korea, dem. rep." = "south korea",
                      "korea. rep." = "north korea",
                      "tanzania" = "united republic of tanzania",
                      "serbia" = "republic of serbia",
                      "taiwan*" = "taiwan",
                      "burma" = "myanmar",
                      "cote d'ivoire" = "ivory coast",
                      "eswatini" = "swaziland",
                      "guinea-bissau" = "guinea bissau",
                      "korea" = "south korea"))
       

choroplethr::country_choropleth(covid.cases.by.country2) +
scale_fill_brewer(palette="Reds") +
  labs(title = "World Covid-19 Cases",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data
                  https://github.com/CSSEGISandData/COVID-19") + 
       theme_minimal()

# data(country.map, package = "choroplethrMaps")
# sort(unique(country.map$region), decreasing = FALSE)
# ggplot(country.map, aes(long, lat, group=group)) + geom_polygon()

##to do, weight by population density

###HEAT MAPPPP!!
##Cases trending by country
cases.daily.agg <- aggregate(covid_melt4$value, 
                             by=list(covid_melt4$ID, 
                                     covid_melt4$Date), 
                             sum)
colnames(cases.daily.agg) = c("ID", "date", "value")

#cases.daily.agg %>% filter( cases.daily.agg$date == "2020-01-22")

cases.monthly.agg <- cases.daily.agg %>% 
                            mutate("month" = as.yearmon(date))

cases.monthly.by.country <- cases.monthly.agg %>% 
                              left_join(countries)
                              

#cases.monthly.by.country %>% filter( cases.monthly.by.country$date == "2020-01-22")

cases.monthly.by.country <- cases.monthly.by.country[c("Country.Region", 
                                                       "month", 
                                                       "value")]

cases.monthly.by.country.agg <- aggregate(cases.monthly.by.country$value,
                                          by=list(cases.monthly.by.country$month,
                                                  cases.monthly.by.country$Country.Region),
                                          sum)

colnames(cases.monthly.by.country.agg) <- c("Month", "Country", "Cases")

x <- dcast(cases.monthly.by.country.agg, 
                     Country ~ Month, 
                     value.var = "Cases") %>%
      tibble::column_to_rownames('Country')

y <- pivot_wider(cases.monthly.by.country, 
            id_cols = "Country.Region")


superheat(x,
          left.label.text.size=2,
          bottom.label.text.size=2,
          bottom.label.size = .05) +
  labs(title = "Worldwide Covid-19 Cases before Vaccines",
       caption = "Source: Johns Hopkins University CSSE Covid-19 data") + 
  theme_minimal()


##Correlation plot
#vaccination, tests, cases
cor_data <- dplyr::select_if(combined.covid.curve, is.numeric)
cor <- cor(cor_data, use="complete.obs")
round(cor,2)



#####PREDICTION TIME!!!
##holidays, restrictions
holidays.20.21 <- data.frame( holiday = c("2020-01-01", "2020-02-14", "2020-02-25",
                          "2020-03-17", "2020-04-12", "2020-05-13", "2020-10-31", 
                          "2020-11-26", "2020-12-25", "2020-12-31", "2021-01-01", 
                          "2021-02-12", "2021-02-14", "2021-02-16", "2021-03-17", 
                          "2021-04-04", "2021-05-24", "2021-10-31", "2021-11-25", 
                          "2021-12-01", "2021-12-25", "2021-12-31"))

holidays.20.21$holiday <- as.Date(holidays.20.21$holiday)

daily.cases.agg <- combined.covid.curve %>%
                    mutate("Holiday" = dateMatch(Date, 
                                                 holidays.20.21$holiday, 
                                                 nomatch = 0))
                      

#holiday days value
#loop through all the dates, if there is a holiday, store that date and 7 days 
#after it - the incubation period for the virus is avg 5-6 days, but can take
#14 days. I took the midpoint.

holiday.covid.incub <- data.frame(nrow(daily.cases.agg))
daily.cases.agg <- daily.cases.agg %>% mutate("Covid.Watch"= 0)
##daily.cases.agg$Covid.Watch <- NULL

for (day in 1:nrow(daily.cases.agg)) {
  
  h.date <- daily.cases.agg[day, "Date"]
  h.is.holiday <- daily.cases.agg[day, "Holiday"]
  
  if(h.is.holiday > 0){
    
    daily.cases.agg[day, "Covid.Watch"] = 1
    
    for (i in 1:9) {
      daily.cases.agg[day+i, "Covid.Watch"] = 1
      }

  }
  
}


###Linear
cases.lm <- lm ( Cases ~ Covid.Watch + Tested + Vaccinated, 
                data = daily.cases.agg)

kable(coef(summary(cases.lm)))

#https://www.simplypsychology.org/p-value.html
##basically, with that pvalue, Covid.Watch is statistically significant to the 
##number of covid cases


###Logistic
cases.glm <- glm(Covid.Watch ~ Cases + Tested + Vaccinated, 
                 data = daily.cases.agg)

kable(coef(summary(cases.glm)))
                  
                           






