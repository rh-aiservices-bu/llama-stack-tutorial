import express from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { z } from "zod";

const NWS_API_BASE = "https://api.weather.gov";
const USER_AGENT = "weather-app/1.0";

// Create server instance
const server = new McpServer({
    name: "weather",
    version: "1.0.0",
});

// Helper function for making NWS API requests
async function makeNWSRequest(url) {
    const headers = {
        "User-Agent": USER_AGENT,
        Accept: "application/geo+json",
    };
    try {
        const response = await fetch(url, { headers });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error("Error making NWS request:", error);
        return null;
    }
}

// Register the tool
server.tool(
    "getforecast",
    "Get real time weather forecast for a location",
    {
        latitude: z.string().describe("Latitude of the location"),
        longitude: z.string().describe("Longitude of the location"),
    },
    async ({ latitude, longitude }) => {
        const pointsUrl = `${NWS_API_BASE}/points/${parseFloat(latitude).toFixed(4)},${parseFloat(longitude).toFixed(4)}`;
        const pointsData = await makeNWSRequest(pointsUrl);
        if (!pointsData) {
            return {
                content: [{
                    type: "text",
                    text: `Failed to retrieve grid point data for coordinates: ${latitude}, ${longitude}. This location may not be supported by the NWS API (only US locations are supported).`
                }],
            };
        }

        const forecastUrl = pointsData.properties?.forecast;
        if (!forecastUrl) {
            return {
                content: [{
                    type: "text",
                    text: "Failed to get forecast URL from grid point data"
                }],
            };
        }

        const forecastData = await makeNWSRequest(forecastUrl);
        if (!forecastData) {
            return {
                content: [{
                    type: "text",
                    text: "Failed to retrieve forecast data"
                }],
            };
        }

        const periods = forecastData.properties?.periods || [];
        if (periods.length === 0) {
            return {
                content: [{
                    type: "text",
                    text: "No forecast periods available"
                }],
            };
        }

        const formattedForecast = periods.map((period) =>
            [
                `${period.name || "Unknown"}:`,
                `Temperature: ${period.temperature || "Unknown"}°${period.temperatureUnit || "F"}`,
                `Wind: ${period.windSpeed || "Unknown"} ${period.windDirection || ""}`,
                `${period.shortForecast || "No forecast available"}`,
                "---",
            ].join("\n")
        );

        const forecastText = `Forecast for ${latitude}, ${longitude}:\n\n${formattedForecast.join("\n")}`;
        return {
            content: [{
                type: "text",
                text: forecastText,
            }],
        };
    }
);

// Start SSE transport using Express
async function main() {
    const app = express();


    
    let transport;
    
    app.get("/sse", async (req, res) => {
      console.log("Received connection");
      transport = new SSEServerTransport("/message", res);
      await server.connect(transport);
    
      server.onclose = async () => {
        await cleanup();
        await server.close();
        process.exit(0);
      };
    });
    
    app.post("/message", async (req, res) => {
      console.log("Received message");
    
      await transport.handlePostMessage(req, res);
    });
    
    const PORT = process.env.PORT || 3001;
    app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}`);
    });
}

main().catch((error) => {
    console.error("Fatal error in main():", error);
    process.exit(1);
});
