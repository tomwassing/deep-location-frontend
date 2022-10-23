<template>
  <div id="mapContainer" class="basemap"></div>
</template>

<script>
import mapboxgl from "mapbox-gl";
import data from "../data/temp.json";
import S2 from "s2-geometry";
import * as turf from '@turf/turf'

export default {
  name: "BaseMap",
  data() {
    return {
      accessToken: "pk.eyJ1IjoidG9td2Fzc2luZyIsImEiOiJjbDlsYTlxbHcwYTBzM3dwY3FmNDE2cGRkIn0.n-CxBweE9w8WUlca9aMyQA",
    };
  },
  mounted() {
    mapboxgl.accessToken = this.accessToken;

    const map = new mapboxgl.Map({
      container: "mapContainer",
      style: "mapbox://styles/mapbox/streets-v11",
      center: [4.866780, 52.334179],
      zoom: 8,
    });


      // extend mapboxGL Marker so we can pass in an onClick handler
        class ClickableMarker extends mapboxgl.Marker {
      // new method onClick, sets _handleClick to a function you pass in
      onClick(handleClick) {
        this._handleClick = handleClick;
        return this;
      }

      // the existing _onMapClick was there to trigger a popup
      // but we are hijacking it to run a function we define
      _onMapClick(e) {
        const targetElement = e.originalEvent.target;
        const element = this._element;

        if (this._handleClick && (targetElement === element || element.contains((targetElement)))) {
          this._handleClick();
        }
      }
    };

    const geojson = {
        'type': 'FeatureCollection',
        'features': []
    };

    const linestring = {
        'type': 'Feature',
        "properties": {},
        'geometry': {
        'type': 'LineString',
        'coordinates': []
        }
    };

    map.on('load', () => {

      map.addSource('geojson', {
        'type': 'geojson',
        'data': geojson
        });
        

        map.addLayer({
          id: 'distanceline',
          type: 'line',
          source: 'geojson',
          layout: {
            'line-cap': 'round',
            'line-join': 'round',
          },
          paint: {
            'line-color': 'gray',
            'line-width': 1.5,
            'line-dasharray': [6, 3],
          },
          filter: ['in', '$type', 'LineString']
        });

          map.addLayer({
              "id": "symbols",
              "type": "symbol",
              "source": "geojson",
              "layout": {
                  "symbol-placement": "line-center",
                  "text-field": '{title}',
                  "text-size": 24
              },
              "paint": {}
          });

      for (const entry of data) {
        const marker = new ClickableMarker()
          .setLngLat([entry.lon, entry.lat])
          .onClick(() => { // onClick() is a thing now!
            const popup = new mapboxgl.Popup()
            .setLngLat([entry.lon, entry.lat])
            .setHTML('<h1>' + entry.lon + '</h1>')
            .addTo(map);

            const latlng = S2.S2.idToLatLng(parseInt(entry.S2CellId, 16).toString());
            const predictedLocation = [latlng.lng, latlng.lat]

            const predictedMarker = new mapboxgl.Marker({color: 'red'})
            .setLngLat(predictedLocation)
            .addTo(map);

            map.fitBounds([[entry.lon, entry.lat],[latlng.lng, latlng.lat]], {
              padding: 100
            });

            linestring.geometry.coordinates = [[entry.lon, entry.lat], predictedLocation]

            const distance = turf.distance([entry.lon, entry.lat], predictedLocation);

            linestring.properties.title = distance.toLocaleString() + ' km';

            geojson.features.push(linestring);

            map.getSource('geojson').setData(geojson);

            popup.on('close', () => {
              linestring.geometry.coordinates = [];
              map.getSource('geojson').setData(geojson);

              predictedMarker.remove();
            });
        }).addTo(map);
      }
      });
  },
};
</script>


<style scoped>
body { margin: 0; padding: 0; }

#mapContainer {
    width: 100vw;
    height: 100vh;
}



</style>