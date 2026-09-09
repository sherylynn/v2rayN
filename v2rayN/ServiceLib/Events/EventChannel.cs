namespace ServiceLib.Events;

public sealed class EventChannel<T>
{
    private readonly Signal<T> _signal = new();
#if NET9_0_OR_GREATER
    private readonly Lock _gate = new();
#else
    // System.Threading.Lock was introduced after .NET 8. A plain monitor object
    // preserves the same synchronization semantics for the Monterey build.
    private readonly object _gate = new();
#endif
    private readonly IObservable<T> _observable;

    public EventChannel()
    {
        _observable = _signal.Synchronize(_gate);
    }

    public IObservable<T> AsObservable()
    {
        return _observable;
    }

    public void Publish(T value)
    {
        lock (_gate)
        {
            _signal.OnNext(value);
        }
    }

    public void Publish()
    {
        if (typeof(T) != typeof(RxVoid))
        {
            throw new InvalidOperationException("Publish() without value is only valid for EventChannel<RxVoid>.");
        }
        lock (_gate)
        {
            _signal.OnNext((T)(object)RxVoid.Default);
        }
    }
}
