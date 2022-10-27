<template>

  <div class="w-100 h-100">
    <div class="fixed-top mx-2 my-2" style="width: 300px">
      <div class="card" style="width: 300px" v-if="current">
        <img :src="current.url" class="card-img-top">
        <div class="card-body">
          <h5 class="card-title">{{ current.title.replaceAll("+", " ") ?? current.id }}</h5>
          <h6 class="card-subtitle mb-2 text-muted">{{ parseDate(current) }}</h6>
          <p class="card-text">
          <h6 class="my-1">Accuracy: <span class="fw-bolder">{{ (current.accuracy * 100).toFixed(2) }}&#x25;</span></h6>
          <div class="progress">
            <div class="progress-bar" :style="{ width: current.accuracy * 100 + '%' }" aria-valuenow="100"
              aria-valuemin="0" aria-valuemax="100"></div>
          </div>
          <h6 class="my-1">Tags</h6>
          <span class="badge bg-primary me-1" v-for="tag in parseTags(current)">{{ tag }}</span>
          </p>
        </div>
      </div>
    </div>
    <div id="mapContainer" class="w-100 vh-100 d-inline-block"></div>
  </div>
</template>

<script>
import mapboxgl from "mapbox-gl";
import groups from "../data/lat_lon_group.json";
import S2 from "s2-geometry";
import * as turf from '@turf/turf';

function myGeoJson() {
  const geojson = {
    'type': 'FeatureCollection',
    'features': []
  };

  for (const group of groups) {
    const parts = group.lat_lon_group.split("_");
    const lat = parseFloat(parts[0]);
    const lon = parseFloat(parts[1]);

    const feature = {
      'type': 'Feature',
      'properties': {
        'id': group.lat_lon_group,
        'count': group.count,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat]
      }
    };

    geojson.features.push(feature);
  }

  return geojson;
}

export default {
  name: "BaseMap",
  data() {
    return {
      accessToken: "pk.eyJ1IjoidG9td2Fzc2luZyIsImEiOiJjbDlsYTlxbHcwYTBzM3dwY3FmNDE2cGRkIn0.n-CxBweE9w8WUlca9aMyQA",
      current: null,
    };
  },
  methods: {
    parseTags(entry) {
      if (entry.tags) {
        return entry.tags.split(",")
          .map((tag) => decodeURIComponent(tag.trim())
            .replaceAll("+", " "));
      }

      return [];
    },
    parseDate(entry) {
      if (entry.year) {
        const date = new Date();
        date.setFullYear(entry.year);
        date.setMonth(entry.month);
        return date.toLocaleDateString();
      }

      return new Date();
    },
  },
  mounted() {
    mapboxgl.accessToken = this.accessToken;

    // Initialize map, zoomed on the VU.
    const map = new mapboxgl.Map({
      container: "mapContainer",
      style: "mapbox://styles/mapbox/streets-v11",
      center: [4.866780, 52.334179],
      zoom: 4,
    });


    // extend mapboxGL Marker so we can pass in an onClick handler, based on:
    // https://bl.ocks.org/chriswhong/8977c0d4e869e9eaf06b4e9fda80f3ab
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

    // Template of GeoJSON data for distance line.
    const geojson = {
      'type': 'FeatureCollection',
      'features': []
    };

    // Template of LineString to show the distance line.
    const linestring = {
      'type': 'Feature',
      "properties": {},
      'geometry': {
        'type': 'LineString',
        'coordinates': []
      }
    };

    map.on('load', () => {

      // Add a GeoJSON source containing place coordinates and information.
      map.addSource('geojson', {
        'type': 'geojson',
        'data': geojson
      });

      // Add a layer to style the distance line.
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

      // Add a layer to style the distance text.
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

      // Add clustesr

      map.addSource('earthquakes', {
        type: 'geojson',
        // Point to GeoJSON data. This example visualizes all M1.0+ earthquakes
        // from 12/22/15 to 1/21/16 as logged by USGS' Earthquake hazards program.
        data: myGeoJson(),
        cluster: true,
        clusterMaxZoom: 5000, // Max zoom to cluster points on
        clusterRadius: 50, // Radius of each cluster when clustering 
        clusterProperties: { // keep separate counts for each magnitude category in a cluster
          "count": ["+", ["get", "count"]]
        }
      });

      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'earthquakes',
        filter: ['has', 'point_count'],
        paint: {
          // Use step expressions (https://docs.mapbox.com/mapbox-gl-js/style-spec/#expressions-step)
          // with three steps to implement three types of circles:
          //   * Blue, 20px circles when point count is less than 100
          //   * Yellow, 30px circles when point count is between 100 and 750
          //   * Pink, 40px circles when point count is greater than or equal to 750
          'circle-color': [
            'step',
            ['get', 'point_count'],
            '#51bbd6',
            100,
            '#f1f075',
            750,
            '#f28cb1'
          ],
          'circle-radius': [
            'step',
            ['get', 'point_count'],
            20,
            100,
            30,
            750,
            40
          ]
        }
      });

      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'earthquakes',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': '{count}',
          'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
          'text-size': 12
        }
      });

      var predictedMarker = null;
      var markers = []

      const setMarkers = (data) => {
        for (const marker of markers) {
          marker.remove();
        }

        for (const entry of data) {
          const marker = new ClickableMarker()
            .setLngLat([entry.lon, entry.lat])
            .onClick(() => {
  
              // Set the current entry.
              this.current = entry;
  
              // Convert predicted location to lat/lon.
              const latlng = S2.S2.idToLatLng(parseInt(entry.S2CellId, 16).toString());
              const predictedLocation = [latlng.lng, latlng.lat]
  
              // Reset the previous predicted marker and distance line.
              if (predictedMarker) {
                predictedMarker.remove();
                linestring.geometry.coordinates = [];
                map.getSource('geojson').setData(geojson);
                predictedMarker = null;
              }
  
              // Add a new predicted marker
              predictedMarker = new mapboxgl.Marker({ color: 'red' })
                .setLngLat(predictedLocation)
                .addTo(map);
  
              // Zoom to show both markers.
              map.fitBounds([[entry.lon, entry.lat], [latlng.lng, latlng.lat]], {
                padding: 100
              });
  
              // Set the distance line start and end.
              linestring.geometry.coordinates = [[entry.lon, entry.lat], predictedLocation]
  
              // Add distance to line.
              const distance = turf.distance([entry.lon, entry.lat], predictedLocation);
              linestring.properties.title = distance.toLocaleString() + ' km';
  
              // Add the line to the map.
              geojson.features.push(linestring);
              map.getSource('geojson').setData(geojson);
  
            }).addTo(map);

          markers.push(marker);
        }
      }

      map.on('zoomend', () => {
        const center = map.getCenter();
        const zoom = map.getZoom();

        const degree = 1;
        const latKey = degree * Math.floor(center.lat / degree);
        const lngKey = degree * Math.floor(center.lng / degree);

        if (zoom > 6) {
          const key = `lat_lon_group=${latKey}_${lngKey}`;
          const url = new URL(`/src/assets/partition/${key}/result.json`, import.meta.url).href;

          fetch(url)
            .then(data => data.text())
            .then(data => {

              const jsonData = data.trim().split("\n").map(JSON.parse);
              setMarkers(jsonData);
            });
        } else {
          // Remove markers as we are zoomed out.
          for (const marker of markers) {
            marker.remove();
          }
          markers = [];
        }

      });

    });
  },
};
</script>


<style scoped>

</style>