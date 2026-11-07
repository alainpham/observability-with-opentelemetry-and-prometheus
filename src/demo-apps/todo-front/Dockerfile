# ---- Build stage: .NET SDK 10.0.402 (latest .NET 10 LTS SDK image on MCR) ----
FROM mcr.microsoft.com/dotnet/sdk:10.0.402 AS build
WORKDIR /src
COPY global.json .
COPY src/HelloWorld/HelloWorld.csproj src/HelloWorld/
RUN dotnet restore src/HelloWorld/HelloWorld.csproj
COPY src/ src/
RUN dotnet publish src/HelloWorld/HelloWorld.csproj -c Release -o /app --no-restore

# ---- Runtime stage: ASP.NET Core 10.0.13 ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0.13 AS runtime
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:7123
EXPOSE 7123
USER 1000
ENTRYPOINT ["dotnet", "HelloWorld.dll"]
