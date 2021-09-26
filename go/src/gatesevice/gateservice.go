package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"encoding/json"
	"time"

	"github.com/stianeikeland/go-rpio"
)

const kPort = 9999
var kPinMap = [...]int{11, 9, 10, 22}
var kNameMap = [...]string{"Main Gate", "Main Garage", "Side Gate", "Second Garage"}

func asyncPushButton(requests chan int, value int) {
	requests <- value
        //fmt.Println("push button %v", value)
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
                //w.Write([]byte("Got It!"))
                http.Redirect(w, r, "/ui", http.StatusFound)
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
		pin.Low()
		//TODO: enable long push 3 seconds versus normal push 0.5 seconds.
//		time.Sleep(3*time.Second)
		time.Sleep(time.Second/2)
		pin.High()
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

func resetBoard() {
  rpio.Open()
  for _, pinNo := range kPinMap {
    pin := rpio.Pin(pinNo)
    pin.Output()
    pin.High()
  }
  rpio.Close()
}

func main() {
	resetBoard()

	// Start request processing loop.
	requests := make(chan int)
	go processRequests(requests)

	// Handle http requests.
	http.HandleFunc("/button", buttonHandler(requests))
	http.HandleFunc("/config", config)
	http.Handle("/images/", http.StripPrefix("/images/", http.FileServer(http.Dir("/data/images"))))
        http.Handle("/ui", http.StripPrefix("/ui", http.FileServer(http.Dir("ui"))))
	fmt.Println("Starting to listen ...")
	log.Fatal(http.ListenAndServe(":"+strconv.Itoa(kPort), nil))
}
