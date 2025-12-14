import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const OPENWEATHERMAP_API_KEY = Deno.env.get('OPENWEATHERMAP_API_KEY')

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Validate API key
        if (!OPENWEATHERMAP_API_KEY) {
            throw new Error('OPENWEATHERMAP_API_KEY is not configured')
        }

        // Parse query parameters
        const url = new URL(req.url)
        const cityName = url.searchParams.get('city')

        if (!cityName) {
            return new Response(
                JSON.stringify({ error: 'City parameter is required' }),
                {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                }
            )
        }

        // Step 1: Geocoding - Get coordinates for the city
        const geoUrl = new URL('https://api.openweathermap.org/geo/1.0/direct')
        geoUrl.searchParams.set('q', `${cityName},JP`)
        geoUrl.searchParams.set('limit', '1')
        geoUrl.searchParams.set('appid', OPENWEATHERMAP_API_KEY)

        const geoResponse = await fetch(geoUrl.toString())

        if (!geoResponse.ok) {
            throw new Error(`Geocoding API returned ${geoResponse.status}`)
        }

        const geoData = await geoResponse.json()

        if (!Array.isArray(geoData) || geoData.length === 0) {
            return new Response(
                JSON.stringify({ error: 'City not found' }),
                {
                    status: 404,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                }
            )
        }

        const locationData = geoData[0]
        const { lat, lon, state: prefectureName, name, local_names } = locationData
        const resolvedCityName = local_names?.ja || name || cityName

        // Step 2: Get weather forecast
        const weatherUrl = new URL('https://api.openweathermap.org/data/2.5/forecast')
        weatherUrl.searchParams.set('lat', lat.toString())
        weatherUrl.searchParams.set('lon', lon.toString())
        weatherUrl.searchParams.set('appid', OPENWEATHERMAP_API_KEY)
        weatherUrl.searchParams.set('units', 'metric')
        weatherUrl.searchParams.set('lang', 'ja')

        const weatherResponse = await fetch(weatherUrl.toString())

        if (!weatherResponse.ok) {
            throw new Error(`Weather API returned ${weatherResponse.status}`)
        }

        const weatherData = await weatherResponse.json()

        // Return the combined response with location info
        const response = {
            ...weatherData,
            cityName: resolvedCityName,
            prefectureName: prefectureName || '',
        }

        return new Response(
            JSON.stringify(response),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        console.error('Error in weather-proxy:', error)
        return new Response(
            JSON.stringify({
                error: error instanceof Error ? error.message : 'Unknown error occurred'
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
