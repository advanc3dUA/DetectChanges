//
//  ModalVC.swift
//  DetectChanges
//
//  Created by Yuriy Gudimov on 24.03.2023.
//

import UIKit
import Combine

final class ModalVC: UIViewController {
    var modalView: ModalView!
    let optionsSubject: CurrentValueSubject<Options, Never>
    var currentDetent: UISheetPresentationController.Detent.Identifier? {
        didSet {
            switch currentDetent?.rawValue {
            case "com.apple.UIKit.large": modalView.showOptionsContent()
            case "small": modalView.hideOptionsContent()
            default: return
            }
        }
    }
    var delegate: ModalVCDelegate?
    private var cancellables: Set<AnyCancellable> = []
    
    init(smallDetentSize: CGFloat, optionsSubject: CurrentValueSubject<Options, Never>) {
        currentDetent = .medium
        self.optionsSubject = optionsSubject
        super.init(nibName: nil, bundle: nil)
        
        // Custom medium detent
        let smallID = UISheetPresentationController.Detent.Identifier("small")
        let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallID) { context in
            return smallDetentSize
        }
        setupSheetPresentationController(with: smallDetent)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - VC Lifecycle
    
    override func loadView() {
        modalView = ModalView()
        view = modalView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGasture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        view.addGestureRecognizer(tapGasture)
        
        modalView.startPauseButton.addTarget(self, action: #selector(startPauseButtonTapped(sender:)), for: .touchUpInside)
        
        saveButtonIsEnabled(false)
        modalView.optionsView.saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        modalView.optionsView.updateOptionsUI(with: optionsSubject.value)
        modalView.optionsView.setLandlordsOption(with: optionsSubject)
        setOptionsPublishers()
    }
    
    @objc func addSaga() {
        optionsSubject.value.landlords[SavingKeys.saga.rawValue] = true
        optionsSubject.send(optionsSubject.value)
    }
    
    @objc func removeSaga() {
        optionsSubject.value.landlords[SavingKeys.saga.rawValue] = false
        optionsSubject.send(optionsSubject.value)
    }
    
    @objc func addVonovia() {
        optionsSubject.value.landlords[SavingKeys.vonovia.rawValue] = true
        optionsSubject.send(optionsSubject.value)
    }
    
    @objc func removeVonovia() {
        optionsSubject.value.landlords[SavingKeys.vonovia.rawValue] = false
        optionsSubject.send(optionsSubject.value)
    }
    
    //MARK: - Button's actions
    
    func saveButtonIsEnabled(_ param: Bool) {
        if param {
            modalView.optionsView.saveButton.alpha = 1.0
            modalView.optionsView.saveButton.isEnabled = true
        } else {
            modalView.optionsView.saveButton.alpha = 0.5
            modalView.optionsView.saveButton.isEnabled = false
        }
    }
    
    @objc func saveButtonTapped() {
        UserDefaults.standard.set(optionsSubject.value.roomsMin, forKey: SavingKeys.roomsMin.rawValue)
        UserDefaults.standard.set(optionsSubject.value.roomsMax, forKey: SavingKeys.roomsMax.rawValue)
        UserDefaults.standard.set(optionsSubject.value.areaMin, forKey: SavingKeys.areaMin.rawValue)
        UserDefaults.standard.set(optionsSubject.value.areaMax, forKey: SavingKeys.areaMax.rawValue)
        UserDefaults.standard.set(optionsSubject.value.rentMin, forKey: SavingKeys.rentMin.rawValue)
        UserDefaults.standard.set(optionsSubject.value.rentMax, forKey: SavingKeys.rentMax.rawValue)
        UserDefaults.standard.set(optionsSubject.value.updateTime, forKey: SavingKeys.updateTime.rawValue)
        UserDefaults.standard.set(optionsSubject.value.soundIsOn, forKey: SavingKeys.soundIsOn.rawValue)
        UserDefaults.standard.set(optionsSubject.value.landlords[SavingKeys.saga.rawValue], forKey: SavingKeys.saga.rawValue)
        UserDefaults.standard.set(optionsSubject.value.landlords[SavingKeys.vonovia.rawValue], forKey: SavingKeys.vonovia.rawValue)
        saveButtonIsEnabled(false)
    }
    
    @objc func startPauseButtonTapped(sender: StartPauseButton) {
        if sender.isOn {
            sender.switchOff()
            delegate?.startEngine()
        } else {
            sender.switchOn()
            delegate?.pauseEngine()
        }
    }
    
    //MARK: - Options publishers
    
    func makeTextFieldIntPublisher(_ textField: UITextField, initialValue: Int) -> AnyPublisher<Int, Never> {
        textField.publisher(for: \.text)
            .map { text in
                Int(extractFrom: text, defaultValue: initialValue)
            }
            .prepend(initialValue)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func setOptionsPublishers() {
        let roomsMinIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.roomsMinTextField, initialValue: optionsSubject.value.roomsMin)
        let roomsMaxIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.roomsMaxTextField, initialValue: optionsSubject.value.roomsMax)
        let areaMinIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.areaMinTextField, initialValue: optionsSubject.value.areaMin)
        let areaMaxIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.areaMaxTextField, initialValue: optionsSubject.value.areaMax)
        let rentMinIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.rentMinTextField, initialValue: optionsSubject.value.rentMin)
        let rentMaxIntPublisher = makeTextFieldIntPublisher(modalView.optionsView.rentMaxTextField, initialValue: optionsSubject.value.rentMax)
        
        let timerUpdateIntPublisher = modalView.optionsView.timerUpdateTextField.publisher(for: \.text)
            .map { [unowned self] textValue in
                Int(extractFrom: textValue, defaultValue: optionsSubject.value.updateTime)
            }
            .scan(nil) { previous, current in
                    if current < 30 {
                        self.modalView.optionsView.timerUpdateTextField.text = "30"
                        if previous == nil || previous == 30 {
                            return nil
                        } else {
                            return 30
                        }
                    } else {
                        return current
                    }
                }
            .compactMap { $0 }
            .removeDuplicates()
        
        let soundSwitchPublisher = modalView.optionsView.soundSwitch.switchPublisher
            .prepend(optionsSubject.value.soundIsOn)

        let roomsPub = Publishers.CombineLatest(roomsMinIntPublisher, roomsMaxIntPublisher)
        let areaPub = Publishers.CombineLatest(areaMinIntPublisher, areaMaxIntPublisher)
        let rentPub = Publishers.CombineLatest(rentMinIntPublisher, rentMaxIntPublisher)
        let updateTimeAndSoundSwitchPub = Publishers.CombineLatest(timerUpdateIntPublisher, soundSwitchPublisher)
        let options = Options()
        
        Publishers.CombineLatest4(roomsPub, areaPub, rentPub, updateTimeAndSoundSwitchPub)
            .dropFirst()
            .map { [unowned self] rooms, area, rent, timeAndSoundSwitch in
                options.roomsMin = rooms.0
                options.roomsMax = rooms.1
                options.areaMin = area.0
                options.areaMax = area.1
                options.rentMin = rent.0
                options.rentMax = rent.1
                options.updateTime = timeAndSoundSwitch.0
                options.soundIsOn = timeAndSoundSwitch.1
                options.landlords[SavingKeys.saga.rawValue] = optionsSubject.value.landlords[SavingKeys.saga.rawValue]
                options.landlords[SavingKeys.vonovia.rawValue] = optionsSubject.value.landlords[SavingKeys.vonovia.rawValue]
                return rooms.0 <= rooms.1 && area.0 <= area.1 && rent.0 <= rent.0
            }
            .sink { [unowned self] isValid in
                saveButtonIsEnabled(isValid)
                optionsSubject.value = options
            }
            .store(in: &cancellables)
    }
    
    //MARK: - Supporting methods
    private func setupSheetPresentationController(with smallDetent: UISheetPresentationController.Detent) {
        sheetPresentationController?.detents = [smallDetent, .large()]
        sheetPresentationController?.largestUndimmedDetentIdentifier = .large
        sheetPresentationController?.prefersScrollingExpandsWhenScrolledToEdge = true
        sheetPresentationController?.prefersEdgeAttachedInCompactHeight = true
        sheetPresentationController?.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.preferredCornerRadius = 10
        
        // Disables hiding TraineeVC
        isModalInPresentation = true
    }
    
    @objc private func hideKeyboard() {
        modalView.optionsView.roomsMinTextField.resignFirstResponder()
        modalView.optionsView.roomsMaxTextField.resignFirstResponder()
        modalView.optionsView.areaMinTextField.resignFirstResponder()
        modalView.optionsView.areaMaxTextField.resignFirstResponder()
        modalView.optionsView.rentMinTextField.resignFirstResponder()
        modalView.optionsView.rentMaxTextField.resignFirstResponder()
        modalView.optionsView.timerUpdateTextField.resignFirstResponder()
    }
}
