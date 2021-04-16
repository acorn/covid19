# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

"""
Analyzing Covid 19 data. 

Data from: https://github.com/CSSEGISandData/COVID-19

COVID-19 Data Repository by the Center for Systems Science and Engineering 
(CSSE) at Johns Hopkins University 

"""

#libraries
import pandas as pd

#loading the raw data. Contains time series reported covid data for all countries
cumulative_data = pd.read_csv('https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv')

last = len(cumulative_data.count()) - 1

cumulative_data_subset = cumulative_data.iloc[:, 1:last]

#global deaths time series
global_deaths = pd.read_csv('https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv')

#testing
testing_data = pd.read_csv('https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/testing/covid-testing-all-observations.csv')

#vaccines
vaccination_data = pd.read_csv('https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/vaccinations/vaccinations.csv')

#countries reporting data
countries = cumulative_data_subset['Country/Region'].drop_duplicates().to_frame()

#adding ISO and merging to one frame
countries_iso = vaccination_data[['location', 'iso_code']].drop_duplicates()

countries_iso = countries_iso.rename(index=str, columns={"location": "Country"})

countries = countries.rename(index=str, columns={"Country/Region": "Country"})

countries = pd.merge(countries, countries_iso, on='Country', how='left')

#add identity/index column
countries["ID"] = countries.index + 1 
 
#merge countries with the case time series data
cumulative_data_subset = cumulative_data_subset.rename(index=str, columns={"Country/Region": "Country"})
merged_covid_cases = pd.merge(cumulative_data_subset, countries, on='Country', how='left')


#vaccination data
vaccination_data_sub = vaccination_data[['location', 'iso_code', 'date', 'total_vaccinations']]
vaccination_data_sub["date"] = pd.to_datetime(vaccination_data_sub["date"])

#merge countries with testing data
testing_data_sub = testing_data[['ISO code', 'Date', 'Cumulative total']]
testing_data_sub = testing_data_sub.rename(index=str, columns={"ISO code": "iso_code", "Date":"date", "Cumulative total": "tests"})
testing_data_sub = pd.merge(testing_data_sub, countries, on='iso_code', how='left')


#Pivoting the merged data to get daily case counts
merged_covid_cases = merged_covid_cases.drop(['Country', 'Lat', 'Long', 'iso_code'], axis=1)

merged_melt = pd.melt(merged_covid_cases, id_vars=['ID']) 

merged_melt = merged_melt.rename(index=str, columns={"variable": "date", "value": "cases"})

merged_melt["date"] = pd.to_datetime(merged_melt["date"])#.dt.date
merged_melt["cases"] = pd.to_numeric(merged_melt["cases"])

##sum by date
merged_melt_agg_bydate = merged_melt.drop(['ID'], axis=1)
merged_melt_agg_bydate = merged_melt_agg_bydate.groupby(["date"]).sum().reset_index()

merged_melt_agg_bydate.plot(x="date", y="cases")

#sum by country - top 10
merged_melt_agg_bycountry = merged_melt.drop(['date'], axis=1)
merged_melt_agg_bycountry = merged_melt_agg_bycountry.groupby(["ID"]).sum().reset_index()
merged_melt_agg_bycountry = merged_melt_agg_bycountry.sort_values(by=['cases'], 
                                                                  ascending=False)
merged_melt_agg_bycountry = pd.merge(merged_melt_agg_bycountry, countries, on='ID', how='left')
merged_melt_agg_bycountry.iloc[0:9, :].plot.bar(x="Country", y="cases")

#testing data plot, tests over worldwide
testing_data_agg_date = testing_data_sub[['date', 'tests']].groupby(['date']).sum().reset_index()
testing_data_agg_date.plot(x="date", y="tests")

#vaccination data plot, worldwide
vaccination_data_agg_date = vaccination_data_sub[['date', 'total_vaccinations']].groupby(['date']).sum().reset_index()
vaccination_data_agg_date.plot(y="total_vaccinations", x="date")

#are top 10 covid countries vacinating proportionally as well
vaccination_data_country = vaccination_data_sub[['location', 'total_vaccinations']].groupby(['location']).sum().reset_index()
#sort
vaccination_data_country = vaccination_data_country.sort_values(by=['total_vaccinations'], ascending=False)
#drop continents
vaccination_data_country = vaccination_data_country.drop(index=[172, 9, 114, 47, 48, 149, 166])
#plot
vaccination_data_country.iloc[0:12, :].plot.bar(x="location", y="total_vaccinations")


#Cases total before and after vaccine
first_dose_date = vaccination_data_sub["date"].min()

cases_before_vaccine = merged_melt_agg_bydate[merged_melt_agg_bydate.date < first_dose_date]
cases_before_vaccine.plot(x="date", y="cases")

cases_after_vaccine = merged_melt_agg_bydate[merged_melt_agg_bydate.date >= first_dose_date]
cases_after_vaccine.plot(x="date", y="cases")


#Daily vaccination totals by country 
vaccination_daily_country = vaccination_data_sub[['iso_code', 'location', 'date', 'total_vaccinations']].groupby(['date']).sum().reset_index()

#vaccination_daily_country = pd.merge(vaccination_daily_country, countries, on='iso_code', how='left')

#Daily vaccination totals by country 
cases_daily_country = merged_melt.groupby(['ID', 'date']).sum().reset_index()

cases_daily_country = pd.merge(cases_daily_country, countries, on='ID', how='left')

# =============================================================================
# cases_vaccines_daily_country = pd.merge(cases_daily_country, vaccination_daily_country, on=['iso_code', 'date'], how='outer')
# 
# cases_vaccines_daily_country = cases_vaccines_daily_country[['date', 'cases', 'Country_x', 'total_vaccinations']]
# 
# cases_vaccines_daily_country = cases_vaccines_daily_country.rename(index=str, columns={"Country_x": "country"})
# 
# 
# =============================================================================

#sort values by
cases_daily_country = cases_daily_country.sort_values(by=['date', 'cases', 'iso_code'], ascending=False)





