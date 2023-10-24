import os
import pandas as pd
import boto3
import requests

from bs4 import BeautifulSoup
from typing import Union
from io import BytesIO
from config import Credentials

class GDPRankingScraper:
    def __init__(self, url: str) -> None:
        self.url = url

    def fetch_content(self) -> Union[BeautifulSoup, None]:
        response = requests.get(self.url)
        if response.status_code == 200:
            return BeautifulSoup(response.content, 'html.parser')
        else:
            print("Failed to fetch the webpage.")
            return None

    def extract_data(self, soup: BeautifulSoup) -> pd.DataFrame:
        gdp_table = soup.find("table", {"id": "example2"})
        headers = [header.text for header in gdp_table.findAll("th")]
        rows = gdp_table.findAll("tr")[1:]

        data = []
        for row in rows:
            rowData = [td.text.strip() for td in row.findAll('td')]
            data.append(rowData)

        return pd.DataFrame(data, columns=headers)

    def scrape(self) -> pd.DataFrame:
        soup = self.fetch_content()
        if soup:
            return self.extract_data(soup)
        raise Exception

    def send_to_s3(self, df: pd.DataFrame, bucket: str, filename: str) -> None:
        output = BytesIO()
        df.to_parquet(output)
        output.seek(0)

        s3 = boto3.client('s3')

        return s3.put_object(Bucket=bucket, Key=filename, Body=output.getvalue())
    
    
def main(event, context):
    try:
        scraper = GDPRankingScraper("https://www.worldometers.info/gdp/gdp-by-country/")
        df = scraper.scrape()
        print(df.info())
    except Exception as error:
        print(error)

    try:
        bucket_name = os.environ.get('BUCKET_NAME')
        filename = os.environ.get('FILENAME')
        scraper.send_to_s3(df, bucket_name, filename)

        print("Successfully uploaded data to S3 Bucket!")
    except Exception as error:
        print(error)
