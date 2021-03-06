library(ggplot2)
library(Rcpp)
# library(cairo) for better fig in Linux
library(shiny)

ui <- fluidPage(
  tags$h1("TCR Sequences",
          style = "font-family: 'Imgact'; color: #00008B;"),
  tags$hr(),
  selectInput("select_data", "Select data demo, user's data or raw TCR sequences",
              c("Data demo" = "d",
                "User's data" = "u",
                "TCR sequences = t")),
  fileInput("tcr_file","Upload the .csv file (format as: tcr,x,y,color)",
            multiple=FALSE,
            accept=c(".csv")
  ),
  downloadButton('download_file', 'Download analyzed results'),

  # Interactive plot
  tags$h4("Brush to zoom the target region"),
  fluidRow(
    column(
      width = 6,
      plotOutput(
        "plot_tcr",
        click = "plot_click",
        brush = brushOpts(id = "plot_brush",
                          resetOnNew = TRUE)
      ),
      verbatimTextOutput("info")
    ),
    column(
      width = 6,
      plotOutput(
        "plot_tcr_z",
        click = "plot_z_click"
      ),
      verbatimTextOutput("info_z")
    )

  )

)

server <- function(input, output) {
  # Initilize ranges for axis
  ranges <- reactiveValues(rx = NULL, ry = NULL)
  ranges_z <- reactiveValues(rzx = NULL, rzy = NULL)
  # Read demo data/user data/TCR seq
  # Read the file as a data frame, 1st line as header, return empty data frame without input
  # Note: a .csv file with only seq column will be treated to generate entire file
  safe.read <- function(docu, slc) {
    if (slc == "d"){
      return(
        read.csv(
          system.file("data/tcr.data.demo.csv", package = "tcrexplorer"),
          header = TRUE,
          sep = ",",
          stringsAsFactors = FALSE
        )
      )
    } else if (is.null(docu)) {
      empdata<-data.frame(tcr=c(NA),x=c(NA),y=c(NA),color=c(NA))
      return(empdata)
    } else if (slc == "u") {
      return(read.csv(
        docu$datapath,
        header = TRUE,
        sep = ",",
        stringsAsFactors = FALSE
      ))
    } else {
      tcr_seq <- read.csv(
        docu$datapath,
        header = TRUE,
        sep = ",",
        stringsAsFactors = FALSE
      )[, 1] # read a data frame with mere seq, get a char vector WITHOUT title
      # analyze with C++, get a data frame
      results <- r.result(tcr_seq)
      return(results)
    }
  }

  # Construct plot with zooming function
  # Left plot with entire data
  output$plot_tcr <- renderPlot({
    ggplot(
      safe.read(input$tcr_file, input$select_data),
      aes(x = x, y = y)) + geom_point() + coord_cartesian(xlim = ranges$rx, ylim = ranges$ry, expand = TRUE) +
      ggtitle("Entire data")
  })

  output$info <- renderPrint({
    nearPoints(safe.read(input$tcr_file, input$select_data),
               input$plot_click,
               xvar = "x",
               yvar = "y",
               addDist = TRUE
    )
  })
  # Right plot for zooming
  output$plot_tcr_z <- renderPlot({
    ggplot(
      safe.read(input$tcr_file, input$select_data),
      aes(x = x, y = y)) + geom_point() + coord_cartesian(xlim = ranges_z$rzx, ylim = ranges_z$rzy, expand = TRUE) +
      ggtitle("Chosen region")
  })
  output$info_z <- renderPrint({
    nearPoints(safe.read(input$tcr_file, input$select_data),
               input$plot_z_click,
               xvar = "x",
               yvar = "y",
               addDist = TRUE
    )
  })
  # Zoom after brush
  observeEvent(input$plot_brush,{
    brush <- input$plot_brush
    if (!is.null(brush)) {
      ranges_z$rzx <- c(brush$xmin, brush$xmax)
      ranges_z$rzy <- c(brush$ymin, brush$ymax)
    } else {
      ranges_z$rzx <- NULL
      ranges_z$rzy <- NULL
    }
  })

  # Generate downloadable file with data frame generated by C++ or from input
  # Row names should be included in the data frame
  output$download_file <- downloadHandler(
    filename = function() {
      paste("TCR_analysis-", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(safe.read(input$tcr_file, input$select_data), file, row.names=FALSE)
    }
  )
}

startTCRExplorer <- function() {
    app <- shiny::shinyApp(ui = ui, server = server)
    shiny::runApp(app)
}
