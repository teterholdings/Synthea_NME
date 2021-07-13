#!/usr/bin/Rscript

# Make heat maps of NME rates and Measles Infections
# Make bar plots of Measles cases per year in the US
# Make regression plots of NME rates in kindergarteners per state per year
# Make a regression plot of Measles cases per year in the US.

# Data requirements:
#  + Synthea generated records.
#  + NME rates by state by year in kindergarteners.
#  + Measles rates in the US each year.

library(rjson)
library(ROpenLayers)


INPUT_DIR <- "/data"
OUTPUT_DIR <- "/output"

SYNTHEA_JSON_FILES <- dir(
	file.path(INPUT_DIR,"fhir")
)

nme.states.df <- read.csv(
	file.path(
		INPUT_DIR,
		"nme_by_state.csv"
	)
)
measles.year.df <- read.csv(
	file.path(
		INPUT_DIR,
		"measles_by_year.csv"
	)
)

plot_regression <- function(x,y,file.name,xlabel="",ylabel="",title=""){
	r <- lm(y~x)
	m <- r$coefficients[["x"]]
	b <- r$coefficients[["(Intercept)"]]
	rsquared = summary(r)$r.squared
	rfunc <- function(z) return(m*z + b)
	xrange <- c(min(x),max(x))
	yrange <- sapply(xrange,rfunc)
	png(file.name,width=600,height=400)
	plot(x,y,pch=19,xlab=xlabel,ylab=ylabel,main=title)
	lines(xrange,yrange,lty=3)
	text(
		xrange[2] - (0.1*(xrange[2]-xrange[1])),
		yrange[1] + (0.1*(yrange[2]-yrange[2])),
		paste(sprintf("R-squared: %1.2f",rsquared))
	)
	dev.off()
}

nme_kindergarteners_state <- function(state,schoolyear.str,nme.df,state.counts){
	schoolyear.start <- as.integer(substr(schoolyear.str,1,4))
	birthdate.start <- as.Date(
		paste(
			schoolyear.start - 6,
			"06",
			"01",
			sep="-"
		)
	)
	birthdate.end <- as.Date(
		paste(
			schoolyear.start - 5,
			"05",
			"31",
			sep = "-"
		)
	)
	nme.rows <- which(
		nme.df$birthdate.date >= birthdate.start &
		nme.df$birthdate.date <= birthdate.end &
		nme.df$state == state
	)
	if((state %in% names(state.counts)) && 
	    (as.character(schoolyear.start - 6) %in% names(state.counts[[state]]))){
		state.count <- state.counts[[state]][[as.character(schoolyear.start - 6)]]
		nme.pct <- length(nme.rows) / state.count
	} else {
		nme.pct <- 0
	}
	return(nme.pct)
}

state.counts <- list()
nme.df <- data.frame(matrix(nrow=0,ncol=5),stringsAsFactors=FALSE)
names(nme.df) <- c("birthdate.str","birthdate.date","latitude","longitude","state")
inf.df <- data.frame(matrix(nrow=0,ncol=5),stringsAsFactors=FALSE)
names(inf.df) <- c("infection.date.str","infection.date","latitude","longitude","state")
for(file.name in SYNTHEA_JSON_FILES){
	f <- file.path(INPUT_DIR,"fhir",file.name)
	long.json <- paste(readLines(f),collapse="")
	json <- fromJSON(long.json)
	nme <- !grepl("MMR",long.json)
	infection <- grepl("Measles",long.json)
	for(e in json[['entry']]){
		if(e[['resource']][['resourceType']] == 'Patient'){
			latitude <- e$resource$address[[1]]$extension[[1]][[2]][[1]]$valueDecimal
			longitude <- e$resource$address[[1]]$extension[[1]][[2]][[2]]$valueDecimal
			birthdate <- e$resource$birthDate
			birthdate.date <- as.Date(birthdate)
			birthplace.state <- e$resource$extension[[5]]$valueAddress$state
			birthyear = substr(birthdate.date,1,4)
			if(nme){
				nme.df <- rbind(
					nme.df,
					data.frame(
						birthdate.str = birthdate,
						birthdate.date = birthdate.date,
						latitude = latitude,
						longitude = longitude,
						state = birthplace.state,
						stringsAsFactors = FALSE
					)
				)
			}
		}
	}
	if(!(birthplace.state %in% names(state.counts))){
		state.counts[[birthplace.state]] <- list()
	}
	if(!(birthyear %in% names(state.counts[[birthplace.state]]))){
		state.counts[[birthplace.state]][[birthyear]] <- 1
	} else {
		state.counts[[birthplace.state]][[birthyear]] <- state.counts[[birthplace.state]][[birthyear]] + 1
	}
	if(infection){
		for(e in json[['entry']]){
			if(e$resource$resourceType == "Condition" && e$resource$code$text == "Measles (disorder)"){
				infection.date.str = substr(e$resource$onsetDateTime,1,10)
				infection.date = as.Date(infection.date.str)
				inf.df <- rbind(
					inf.df,
					data.frame(
						infection.date.str = infection.date.str,
						infection.date = infection.date,
						latitude = latitude,
						longitude = longitude,
						state = birthplace.state,
						stringsAsFactors = FALSE
					)
				)
			}
		}
	}
}



if(nrow(nme.df) == 0){
    cat("No NMEs")
} else {
    nme.heatmap.pts <- nme.df[,c("longitude","latitude")]
    nme.map <- ol_map(
        center=c(-98.5,28.5),
        zoom=4
    ) + 
        public_arcgis_basemap('LightGray') +
        ol_geom_heatmap(
            nme.heatmap.pts,
            name="NME Heat Map",
            toggle.control=TRUE,
            opacity=0.25
            )

    ol_map2HTML(
        nme.map,
        file.path(OUTPUT_DIR,"nme_map.html"),
        map.note="Nonmedical MMR Exemption Density"
    )

    measles.heatmap.pts <- inf.df[,c("longitude","latitude")]
	if(nrow(measles.heatmap.pts) > 0){
		measles.map <- ol_map(
			center=c(-98.5,28.5),
			zoom=4
		) + 
			public_arcgis_basemap('LightGray') +
			ol_geom_heatmap(
				measles.heatmap.pts,
				name="Measles Cases Heat Map",
				toggle.control=TRUE,
				opacity=0.25
				)

		ol_map2HTML(
			measles.map,
			file.path(OUTPUT_DIR,"measles_map.html"),
			map.note="Measles Density from Synthea data"
		)
	}

	measles.heatmap.pts.2015 <- inf.df[substr(inf.df$infection.date.str,1,4) == "2015",c("longitude","latitude")]

	if(nrow(measles.heatmap.pts.2015) > 0){
        	measles.map.2015 <- ol_map(
        	center=c(-98.5,28.5),
        	zoom=4
        	) +
        	public_arcgis_basemap('LightGray') +
        	ol_geom_heatmap(
        		measles.heatmap.pts.2015,
        		name="Measles Cases Heat Map",
        		toggle.control=TRUE,
        		opacity=0.25
        	)
        
        	ol_map2HTML(
        	measles.map.2015,
        	file.path(OUTPUT_DIR,"measles_map_2015.html"),
        	map.note="Measles Density from Synthea data"
        	)
	}

	measles.heatmap.pts.2019 <- inf.df[substr(inf.df$infection.date.str,1,4) == "2019",c("longitude","latitude")]

	if(nrow(measles.heatmap.pts.2019) > 0){
        	measles.map.2019 <- ol_map(
        	center=c(-98.5,28.5),
        	zoom=4
        	) +
        	public_arcgis_basemap('LightGray') +
        	ol_geom_heatmap(
        		measles.heatmap.pts.2019,
        		name="Measles Cases Heat Map",
        		toggle.control=TRUE,
        		opacity=0.25
        	)
        
        	ol_map2HTML(
        	measles.map.2019,
        	file.path(OUTPUT_DIR,"measles_map_2019.html"),
        	map.note="Measles Density from Synthea data"
        	)
	}


	nme.rates <- apply(
		nme.states.df,
		1,
		function(r){
			o <- nme_kindergarteners_state(
				state=r[1],
				schoolyear.str=r[2],
				nme.df=nme.df,
				state.counts=state.counts
			)
			return(o)
		}
	)

	plot_regression(
		0.01 * as.numeric(nme.states.df$coverage_estimate),
		as.numeric(nme.rates),
		file.path(OUTPUT_DIR,"nme_states_reg.png"),
		"CDC State MMR NME Rates in Kindergarteners",
		"Synthea Output MMR NME Rates",
		"Regression of Synthea vs. Actual NME Rates by State"
	)

	measles.infection.years <- sapply(
		inf.df$infection.date.str,
		function(s) return(substr(s,1,4))
	)
	measles.annual.counts <- table(measles.infection.years)

	x <- NULL
	y <- NULL
	for(column in names(measles.year.df)[2:ncol(measles.year.df)]){
		year.str = substr(column,2,5)
		if(year.str %in% names(measles.annual.counts)){
			x <- append(x,measles.year.df[1,column])
			y <- append(y,measles.annual.counts[year.str])
		}
	}

	plot_regression(
		as.numeric(x),
		as.numeric(y),
		file.path(OUTPUT_DIR,"measles_annual_rates_regression.png"),
		"Annual US Measles Rates",
		"Synthea Output Measles Rates",
		"Regression of Synthea vs. Actual US Measles Rates"
	)

	measles.annual.df <- data.frame(
	year = as.integer(names(measles.annual.counts)),
	count = as.numeric(measles.annual.counts)
	)

	measles.annual.df <- measles.annual.df[order(measles.annual.df$year),]
	measles.annual.df.subset <- subset(measles.annual.df,year >= 2010 & year <= 2020)

	png(file.path(OUTPUT_DIR,"measles_annual_counts.png"),width=600,height=400)
	barplot(
		measles.annual.df.subset$count,
		names.arg = measles.annual.df.subset$year,
		ylab="Total Measles Cases",
		xlab = "Year",
		col = 'blue',
		main = "Synthetic Data Annual Measles Counts"
	)
	dev.off()

	save(
	     state.counts,
	     nme.df,
	     inf.df,
	     file = file.path(OUTPUT_DIR,"analysis.RData")
	)
}

