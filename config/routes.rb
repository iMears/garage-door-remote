Rails.application.routes.draw do
  root 'garage_door#index'

  get 'garage_door/press'

  get 'garage_door/status'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
