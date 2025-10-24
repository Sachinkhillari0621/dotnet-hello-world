# Stage 1: Build
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

# Copy solution and project files separately (better caching)
COPY *.sln ./
COPY dotnet-hello-world/*.csproj ./dotnet-hello-world/

# Restore dependencies
RUN dotnet restore

# Copy all source code
COPY . .

# Publish the specific project
RUN dotnet publish ./dotnet-hello-world/dotnet-hello-world.csproj -c Release -o out

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 80
ENTRYPOINT ["dotnet", "dotnet-hello-world.dll"]

