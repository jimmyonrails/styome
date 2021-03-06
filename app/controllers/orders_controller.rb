class OrdersController < ApplicationController

  before_action :authenticate_user!

  def index
    @orders = current_user.orders
  end

  def new
    @order = Order.new
  end

  def create
    @order = current_user.orders.new( order_params )

    current_cart.products.each do |p|
      @order.order_items.build( product_id: p[:product_id],
                                quantity: p[:quantity],
                                amount: p[:amount] )
    end

    if @order.payment_type == "credit" && @order.save
      current_cart.clear

      @payment = PaypalPayment.build(@order, :return_url => approved_order_url(@order),
                                             :cancel_url => root_url)
      if @payment.create
        redirect_to @order.paypal_approval_url
      else
        redirect_to root_path
      end
      # OrderConfirm.confirm(@order).deliver
    elsif @order.payment_type == "atm" && @order.save
      OrderConfirm.confirm(@order).deliver
      current_cart.clear
      flash[:notice] = "感謝你的訂購"
      redirect_to root_path
    else
      render :new
    end
  end

  def approved
    @order = current_user.orders.find(params[:id])
    if params[:paymentId]
      @order.paypal_payer_id = params[:PayerID]
      @order.paypal_return_at = Time.now
      @order.save!
    end
  end

  def execute
    @order = current_user.orders.find(params[:id])
    payment = PaypalPayment.find_by(@order)

    if payment.execute
      flash[:notice] = "感謝你的訂購"
      redirect_to orders_path
    else
      flash[:notice] = "Paypal fail"
      redirect_to orders_path
    end
  end

  def destroy
    @order = Order.find(params[:id])
    @order.destroy
    redirect_to orders_path
  end

  private

  def order_params
    params.require(:order).permit(:receive_name, :receive_address, :payment_type)
  end
end
