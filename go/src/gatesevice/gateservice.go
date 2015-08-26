package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"encoding/json"
	"time"

//	"github.com/oleksandr/bonjour"
	"github.com/stianeikeland/go-rpio"
)

const kPort = 9999
var kPinMap = [...]int{11, 9, 10, 22}
var kNameMap = [...]string{"Main Gate", "Main Garage", "Side Gate", "Second Garage"}

func asyncPushButton(requests chan int, value int) {
	requests <- value
}

func buttonHandler(requests chan int) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		r.ParseForm()
		button, err := strconv.Atoi(r.Form.Get("k"))
		if err == nil {
			go asyncPushButton(requests, button)
		}
		//TODO: remove sleep
                time.Sleep(time.Second)
                w.Write([]byte("Got It!"))
	}
}

func processRequests(requests chan int) {
	for gate := range requests {
		log.Printf("processing request %v", gate)
		if gate < 0 || gate >= len(kPinMap) {
                        log.Printf("Invalid gate number %v", gate)
			continue
		}
		err := rpio.Open()
		if err != nil {
			log.Println("Cant open GPIO")
			continue
		}
		pin := rpio.Pin(kPinMap[gate])
		pin.Output()
		pin.High()
		time.Sleep(time.Second)
		pin.Low()
		rpio.Close()
		time.Sleep(time.Second)
	}
}

func config(w http.ResponseWriter, r *http.Request) {
        msg, err := json.Marshal(kNameMap)
        if err == nil {
                w.Write(msg)
        } else {
                http.Error(w, "can't read config", 500)
        }
}

func main() {
	// Run registration.
//	_, err := bonjour.Register("gateopenservice", "_gateservice._tcp.", "", kPort, []string{"txtv=1", "app=test"}, nil)
//	if err != nil {
//		log.Fatalln(err.Error())
//	}
//	fmt.Println("Service registered")

	// Start request processing loop.
	requests := make(chan int)
	go processRequests(requests)

	// Handle http requests.
	http.HandleFunc("/button", buttonHandler(requests))
	http.HandleFunc("/config", config)
	fmt.Println("Starting to listen ...")
	log.Fatal(http.ListenAndServe(":"+strconv.Itoa(kPort), nil))
}
