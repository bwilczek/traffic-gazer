import os
import pprint
import googlemaps
from datetime import datetime

key=os.environ['GOOGLE_MAPS_KEY']

gmaps = googlemaps.Client(key=key)

now = datetime.now()
directions_result = gmaps.directions("Kowalska 190, Wrocław",
                                     "Kowalska 20, Wrocław",
                                     mode="driving",
                                     departure_time=now)

pp = pprint.PrettyPrinter(indent=2)
pp.pprint(directions_result)

