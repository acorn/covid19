#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Apr  5 18:10:47 2021

@author: yinyang
"""

##Interactive app time
import dash as d
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output
from covid19 import merged_melt_agg_bydate, vaccination_daily_country, cases_daily_country

app = d.Dash(__name__)

app.layout = html.Div(
    children=[
        html.Div(
        children=[
        html.H1(children="Covid-19 Country Analysis",
                className="header-title",),
        html.P(
            children="Select the country from the drop down to"
            " see the trend of cases, testing and vaccinations"
            "",
            className="header-description",
            ),
        ], 
    className="header",
    ),
    html.Div(
        children=[
            html.Div(
            children=[
            dcc.Dropdown(
                id="case-country-filter",
                options=[
                    {"label": Country, "value": Country}
                    for Country in cases_daily_country.Country.unique()
                ],
                value="Argentina",
                clearable=False,
                className="dropdown",
        ),
        ],
        ),
        html.Div(
                children=[
            dcc.DatePickerRange(
                id="date-range",
                min_date_allowed=merged_melt_agg_bydate.date.min().date(),
                max_date_allowed=merged_melt_agg_bydate.date.max().date(),
                start_date=merged_melt_agg_bydate.date.min().date(),
                end_date=merged_melt_agg_bydate.date.max().date(),
            ),
        ],
        ),
        ],
    className="menu",
    ),
    html.Div(
        children=[
            html.Div(
                children=dcc.Graph(
                    id="cases-chart", config={"displayModeBar": False},
                ),
                className="card",
            ),
               html.Div(
                children=dcc.Graph(
                    id="vaccinations-chart", config={"displayModeBar": False},
                ),
                className="card",
        ),
    ],
    className="wrapper",
    ), 
    ]
)

@app.callback(
    [Output("cases-chart", "figure"), Output("vaccinations-chart", "figure")],
    [
        Input("date-range", "start_date"),
        Input("date-range", "end_date"),
    ],
)
def update_charts(cases, start_date, end_date):
    mask = (

        (merged_melt_agg_bydate.date >= start_date)
        & (merged_melt_agg_bydate.date <= end_date)
    )
    
    filtered_data = merged_melt_agg_bydate.loc[mask, :]
    #vac_filtered_data = vaccination_daily_country.loc[mask, :]
   
    cases_chart_figure = {
        "data": [
            {
                "x": filtered_data["date"],
                "y": filtered_data["cases"],
                "type": "lines",
                "hovertemplate": "$%{y:.2f}<extra></extra>",
            },
        ],
        "layout": {
            "title": {
                "text": "Cases over Period",
                "x": 0.05,
                "xanchor": "left",
            },
            "xaxis": {"fixedrange": True},
            "yaxis": {"tickprefix": "", "fixedrange": True},
            "colorway": ["#17B897"],
        },
    }

    # vaccinations_chart_figure = {
    #     "data": [
    #         {
    #             "x": vac_filtered_data["date"],
    #             "y": vac_filtered_data["total_vaccinations"],
    #             "type": "lines",
    #         },
    #     ],
    #     "layout": {
    #         "title": {
    #             "text": "Vaccinations Administered",
    #             "x": 0.05,
    #             "xanchor": "left"
    #         },
    #         "xaxis": {"fixedrange": True},
    #         "yaxis": {"fixedrange": True},
    #         "colorway": ["#E12D39"],
    #     },
    # }
    return cases_chart_figure#, vaccinations_chart_figure

if __name__ == "__main__":
    app.run_server(debug=True)
